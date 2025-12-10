//
//  PKCancellationToken.m
//  PlugInKit
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

#import "PKCancellationToken.h"

@interface PKCancellationToken ()
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong) NSMutableArray<void (^)(void)> *handlers;
@property (nonatomic, assign) BOOL cancelled;
@end

@implementation PKCancellationToken

- (instancetype)init {
    self = [super init];
    if (self) {
        _queue = dispatch_queue_create("com.pluginkit.cancellation", DISPATCH_QUEUE_SERIAL);
        _handlers = [NSMutableArray array];
        _cancelled = NO;
    }
    return self;
}

- (BOOL)isCancelled {
    __block BOOL cancelled = NO;
    dispatch_sync(self.queue, ^{
        cancelled = self.cancelled;
    });
    return cancelled;
}

- (void)cancel {
    NSArray<void (^)(void)> *handlersToInvoke = nil;

    dispatch_sync(self.queue, ^{
        if (self.cancelled) {
            return;
        }

        self.cancelled = YES;
        handlersToInvoke = [self.handlers copy];
        [self.handlers removeAllObjects];
    });

    // Invoke handlers outside of lock
    for (void (^handler)(void) in handlersToInvoke) {
        handler();
    }
}

- (void)onCancelled:(void (^)(void))handler {
    if (!handler) {
        return;
    }

    __block BOOL shouldInvokeImmediately = NO;

    dispatch_sync(self.queue, ^{
        if (self.cancelled) {
            shouldInvokeImmediately = YES;
        } else {
            [self.handlers addObject:[handler copy]];
        }
    });

    if (shouldInvokeImmediately) {
        handler();
    }
}

+ (instancetype)linkedTokenWithTokens:(NSArray<PKCancellationToken *> *)tokens {
    PKCancellationToken *linkedToken = [[PKCancellationToken alloc] init];

    for (PKCancellationToken *token in tokens) {
        [token onCancelled:^{
            [linkedToken cancel];
        }];
    }

    return linkedToken;
}

@end
