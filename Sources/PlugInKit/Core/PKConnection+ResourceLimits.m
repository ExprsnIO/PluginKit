//
//  PKConnection+ResourceLimits.m
//  PlugInKit
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

#import "PKConnection+ResourceLimits.h"
#import "PKError.h"
#import "../../PlugInKitProtocol/PKPlugInProtocol.h"
#import <objc/runtime.h>

/// Mutable governance state for a single connection, held as one associated
/// object so the category does not need multiple stored properties.
@interface PKConnectionResourceState : NSObject
@property (nonatomic, strong) NSCondition *lock;
/// Operations that are running (have acquired a concurrency slot).
@property (nonatomic, assign) NSUInteger activeCount;
/// Operations submitted but not yet finished (running + waiting for a slot).
@property (nonatomic, assign) NSUInteger pendingCount;
@property (nonatomic, assign) NSUInteger maxConcurrentOperations;
@property (nonatomic, assign) NSTimeInterval operationTimeout;
@property (nonatomic, assign) NSUInteger maxQueuedMessages;
@property (nonatomic, strong) dispatch_queue_t gateQueue;
@end

@implementation PKConnectionResourceState

- (instancetype)init {
    if (self = [super init]) {
        _lock = [[NSCondition alloc] init];
        _maxConcurrentOperations = NSUIntegerMax;
        _maxQueuedMessages = NSUIntegerMax;
        _operationTimeout = 0.0;
        _gateQueue = dispatch_queue_create("com.pluginkit.connection.resourcegate",
                                           DISPATCH_QUEUE_CONCURRENT);
    }
    return self;
}

/// Total admission capacity (concurrency slots + waiting room), saturating.
- (NSUInteger)capacity {
    if (_maxConcurrentOperations == NSUIntegerMax || _maxQueuedMessages == NSUIntegerMax) {
        return NSUIntegerMax;
    }
    NSUInteger sum = _maxConcurrentOperations + _maxQueuedMessages;
    return (sum < _maxConcurrentOperations) ? NSUIntegerMax : sum;  // overflow guard
}

@end

static const void *PKConnectionResourceStateKey = &PKConnectionResourceStateKey;

@implementation PKConnection (ResourceLimits)

- (PKConnectionResourceState *)pk_resourceState {
    @synchronized (self) {
        PKConnectionResourceState *state = objc_getAssociatedObject(self, PKConnectionResourceStateKey);
        if (!state) {
            state = [[PKConnectionResourceState alloc] init];
            objc_setAssociatedObject(self, PKConnectionResourceStateKey, state,
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        return state;
    }
}

// MARK: - Properties

- (NSUInteger)maxConcurrentOperations {
    PKConnectionResourceState *state = [self pk_resourceState];
    [state.lock lock];
    NSUInteger value = state.maxConcurrentOperations;
    [state.lock unlock];
    return value;
}

- (void)setMaxConcurrentOperations:(NSUInteger)maxConcurrentOperations {
    PKConnectionResourceState *state = [self pk_resourceState];
    [state.lock lock];
    state.maxConcurrentOperations = MAX(maxConcurrentOperations, (NSUInteger)1);
    // A larger cap may now permit waiting operations to proceed.
    [state.lock broadcast];
    [state.lock unlock];
}

- (NSTimeInterval)operationTimeout {
    PKConnectionResourceState *state = [self pk_resourceState];
    [state.lock lock];
    NSTimeInterval value = state.operationTimeout;
    [state.lock unlock];
    return value;
}

- (void)setOperationTimeout:(NSTimeInterval)operationTimeout {
    PKConnectionResourceState *state = [self pk_resourceState];
    [state.lock lock];
    state.operationTimeout = MAX(operationTimeout, 0.0);
    [state.lock unlock];
}

- (NSUInteger)maxQueuedMessages {
    PKConnectionResourceState *state = [self pk_resourceState];
    [state.lock lock];
    NSUInteger value = state.maxQueuedMessages;
    [state.lock unlock];
    return value;
}

- (void)setMaxQueuedMessages:(NSUInteger)maxQueuedMessages {
    PKConnectionResourceState *state = [self pk_resourceState];
    [state.lock lock];
    state.maxQueuedMessages = MAX(maxQueuedMessages, (NSUInteger)1);
    [state.lock unlock];
}

- (NSUInteger)currentQueueDepth {
    PKConnectionResourceState *state = [self pk_resourceState];
    [state.lock lock];
    NSUInteger waiting = (state.pendingCount > state.activeCount)
        ? (state.pendingCount - state.activeCount) : 0;
    [state.lock unlock];
    return waiting;
}

// MARK: - Governed Operations

- (void)performGovernedOperation:(void (^)(id<PKPlugInProtocol> plugin, void (^done)(void)))operationBlock
                      completion:(nullable void (^)(NSError * _Nullable error))completion {
    if (!operationBlock) {
        if (completion) {
            completion([NSError pk_errorWithCode:PKErrorInvalidArgument
                                     description:@"operationBlock must not be nil"]);
        }
        return;
    }

    PKConnectionResourceState *state = [self pk_resourceState];

    if (self.isSuspended) {
        if (completion) {
            completion([NSError pk_errorWithCode:PKErrorPlugInSuspended
                                     description:@"Connection is suspended"
                                        userInfo:@{PKErrorPlugInIdentifierKey: self.plugInIdentifier}]);
        }
        return;
    }

    // Admission control: reject synchronously if the connection is at capacity.
    [state.lock lock];
    if (state.pendingCount >= [state capacity]) {
        [state.lock unlock];
        if (completion) {
            completion([NSError pk_errorWithCode:PKErrorQueueFull
                                     description:@"Operation queue is full"
                                        userInfo:@{PKErrorPlugInIdentifierKey: self.plugInIdentifier}]);
        }
        return;
    }
    state.pendingCount++;
    [state.lock unlock];

    dispatch_async(state.gateQueue, ^{
        // Wait for a concurrency slot.
        [state.lock lock];
        while (state.activeCount >= state.maxConcurrentOperations) {
            [state.lock wait];
        }
        state.activeCount++;
        [state.lock unlock];

        [self beginOperation];

        __block BOOL finished = NO;
        void (^finishOnce)(NSError *) = ^(NSError *opError) {
            [state.lock lock];
            if (finished) {
                [state.lock unlock];
                return;
            }
            finished = YES;
            if (state.activeCount > 0) {
                state.activeCount--;
            }
            if (state.pendingCount > 0) {
                state.pendingCount--;
            }
            [state.lock broadcast];
            [state.lock unlock];

            [self endOperation];
            if (completion) {
                completion(opError);
            }
        };

        NSTimeInterval timeout = state.operationTimeout;
        if (timeout > 0) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeout * NSEC_PER_SEC)),
                           state.gateQueue, ^{
                finishOnce([NSError pk_errorWithCode:PKErrorOperationTimedOut
                                         description:@"Governed operation exceeded its timeout"
                                            userInfo:@{PKErrorPlugInIdentifierKey: self.plugInIdentifier}]);
            });
        }

        id<PKPlugInProtocol> plugin = [self remotePlugInWithErrorHandler:^(NSError *error) {
            finishOnce(error);
        }];

        operationBlock(plugin, ^{
            finishOnce(nil);
        });
    });
}

@end
