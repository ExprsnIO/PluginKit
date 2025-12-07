//
//  PKFuture.m
//  PlugInKit
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

#import "PKFuture.h"

NSErrorDomain const PKFutureErrorDomain = @"com.pluginkit.future";

@interface PKFuture ()

@property (nonatomic, assign, readwrite) PKFutureState state;
@property (nonatomic, strong, readwrite, nullable) id value;
@property (nonatomic, strong, readwrite, nullable) NSError *error;
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong) dispatch_semaphore_t semaphore;
@property (nonatomic, strong) NSMutableArray<void (^)(id _Nullable value, NSError * _Nullable error)> *callbacks;

@end

@implementation PKFuture

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (instancetype)init {
    if (self = [super init]) {
        _state = PKFutureStatePending;
        _queue = dispatch_queue_create("com.pluginkit.future", DISPATCH_QUEUE_SERIAL);
        _semaphore = dispatch_semaphore_create(0);
        _callbacks = [NSMutableArray array];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeInteger:self.state forKey:@"state"];
    [coder encodeObject:self.value forKey:@"value"];
    [coder encodeObject:self.error forKey:@"error"];
}

- (nullable instancetype)initWithCoder:(NSCoder *)coder {
    if (self = [self init]) {
        PKFutureState state = [coder decodeIntegerForKey:@"state"];
        id value = [coder decodeObjectForKey:@"value"];
        NSError *error = [coder decodeObjectOfClass:[NSError class] forKey:@"error"];

        if (state == PKFutureStateFulfilled) {
            [self fulfillWithValue:value];
        } else if (state == PKFutureStateRejected) {
            [self rejectWithError:error];
        }
    }
    return self;
}

// MARK: - Creation

+ (instancetype)futureWithResolver:(void (^)(void (^fulfill)(id _Nullable), void (^reject)(NSError *)))resolver {
    PKFuture *future = [[self alloc] init];

    void (^fulfill)(id _Nullable) = ^(id _Nullable value) {
        [future fulfillWithValue:value];
    };

    void (^reject)(NSError *) = ^(NSError *error) {
        [future rejectWithError:error];
    };

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        resolver(fulfill, reject);
    });

    return future;
}

+ (instancetype)fulfilledWithValue:(nullable id)value {
    PKFuture *future = [[self alloc] init];
    [future fulfillWithValue:value];
    return future;
}

+ (instancetype)rejectedWithError:(NSError *)error {
    PKFuture *future = [[self alloc] init];
    [future rejectWithError:error];
    return future;
}

// MARK: - Internal Resolution

- (void)fulfillWithValue:(nullable id)value {
    dispatch_async(self.queue, ^{
        if (self.state != PKFutureStatePending) return;

        self.state = PKFutureStateFulfilled;
        self.value = value;

        dispatch_semaphore_signal(self.semaphore);

        for (void (^callback)(id, NSError *) in self.callbacks) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                callback(value, nil);
            });
        }

        [self.callbacks removeAllObjects];
    });
}

- (void)rejectWithError:(NSError *)error {
    dispatch_async(self.queue, ^{
        if (self.state != PKFutureStatePending) return;

        self.state = PKFutureStateRejected;
        self.error = error;

        dispatch_semaphore_signal(self.semaphore);

        for (void (^callback)(id, NSError *) in self.callbacks) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                callback(nil, error);
            });
        }

        [self.callbacks removeAllObjects];
    });
}

- (void)addCallback:(void (^)(id _Nullable value, NSError * _Nullable error))callback {
    dispatch_async(self.queue, ^{
        if (self.state == PKFutureStatePending) {
            [self.callbacks addObject:callback];
        } else {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                callback(self.value, self.error);
            });
        }
    });
}

- (BOOL)isCompleted {
    return self.state != PKFutureStatePending;
}

// MARK: - Transformation

- (PKFuture *)then:(PKFutureTransform)transform {
    return [PKFuture futureWithResolver:^(void (^fulfill)(id _Nullable), void (^reject)(NSError *)) {
        [self addCallback:^(id _Nullable value, NSError * _Nullable error) {
            if (error) {
                reject(error);
            } else {
                @try {
                    id result = transform(value);
                    fulfill(result);
                } @catch (NSException *exception) {
                    NSError *err = [NSError errorWithDomain:PKFutureErrorDomain
                                                       code:PKFutureErrorInvalidState
                                                   userInfo:@{NSLocalizedDescriptionKey: exception.reason ?: @"Transform failed"}];
                    reject(err);
                }
            }
        }];
    }];
}

- (PKFuture *)thenFuture:(PKFuture * _Nullable (^)(id _Nullable))transform {
    return [PKFuture futureWithResolver:^(void (^fulfill)(id _Nullable), void (^reject)(NSError *)) {
        [self addCallback:^(id _Nullable value, NSError * _Nullable error) {
            if (error) {
                reject(error);
            } else {
                @try {
                    PKFuture *nextFuture = transform(value);
                    if (nextFuture) {
                        [nextFuture addCallback:^(id _Nullable nextValue, NSError * _Nullable nextError) {
                            if (nextError) {
                                reject(nextError);
                            } else {
                                fulfill(nextValue);
                            }
                        }];
                    } else {
                        fulfill(nil);
                    }
                } @catch (NSException *exception) {
                    NSError *err = [NSError errorWithDomain:PKFutureErrorDomain
                                                       code:PKFutureErrorInvalidState
                                                   userInfo:@{NSLocalizedDescriptionKey: exception.reason ?: @"Transform failed"}];
                    reject(err);
                }
            }
        }];
    }];
}

- (PKFuture *)map:(id _Nullable (^)(id _Nullable))mapper {
    return [self then:mapper];
}

- (PKFuture *)flatMap:(PKFuture * _Nullable (^)(id _Nullable))mapper {
    return [self thenFuture:mapper];
}

// MARK: - Error Handling

- (PKFuture *)catch:(PKFutureRecover)recover {
    return [PKFuture futureWithResolver:^(void (^fulfill)(id _Nullable), void (^reject)(NSError *)) {
        [self addCallback:^(id _Nullable value, NSError * _Nullable error) {
            if (error) {
                @try {
                    id result = recover(error);
                    fulfill(result);
                } @catch (NSException *exception) {
                    NSError *err = [NSError errorWithDomain:PKFutureErrorDomain
                                                       code:PKFutureErrorInvalidState
                                                   userInfo:@{NSLocalizedDescriptionKey: exception.reason ?: @"Recovery failed"}];
                    reject(err);
                }
            } else {
                fulfill(value);
            }
        }];
    }];
}

- (PKFuture *)catchFuture:(PKFuture * _Nullable (^)(NSError *))recover {
    return [PKFuture futureWithResolver:^(void (^fulfill)(id _Nullable), void (^reject)(NSError *)) {
        [self addCallback:^(id _Nullable value, NSError * _Nullable error) {
            if (error) {
                @try {
                    PKFuture *recoveryFuture = recover(error);
                    if (recoveryFuture) {
                        [recoveryFuture addCallback:^(id _Nullable recoveredValue, NSError * _Nullable recoveryError) {
                            if (recoveryError) {
                                reject(recoveryError);
                            } else {
                                fulfill(recoveredValue);
                            }
                        }];
                    } else {
                        fulfill(nil);
                    }
                } @catch (NSException *exception) {
                    NSError *err = [NSError errorWithDomain:PKFutureErrorDomain
                                                       code:PKFutureErrorInvalidState
                                                   userInfo:@{NSLocalizedDescriptionKey: exception.reason ?: @"Recovery failed"}];
                    reject(err);
                }
            } else {
                fulfill(value);
            }
        }];
    }];
}

- (PKFuture *)finally:(void (^)(void))finalizer {
    return [PKFuture futureWithResolver:^(void (^fulfill)(id _Nullable), void (^reject)(NSError *)) {
        [self addCallback:^(id _Nullable value, NSError * _Nullable error) {
            finalizer();
            if (error) {
                reject(error);
            } else {
                fulfill(value);
            }
        }];
    }];
}

// MARK: - Side Effects

- (PKFuture *)onSuccess:(void (^)(id _Nullable))action {
    [self addCallback:^(id _Nullable value, NSError * _Nullable error) {
        if (!error) {
            action(value);
        }
    }];
    return self;
}

- (PKFuture *)onFailure:(void (^)(NSError *))action {
    [self addCallback:^(id _Nullable value, NSError * _Nullable error) {
        if (error) {
            action(error);
        }
    }];
    return self;
}

- (PKFuture *)onComplete:(void (^)(id _Nullable, NSError * _Nullable))action {
    [self addCallback:action];
    return self;
}

// MARK: - Filtering

- (PKFuture *)filter:(BOOL (^)(id _Nullable))predicate {
    NSError *error = [NSError errorWithDomain:PKFutureErrorDomain
                                         code:PKFutureErrorFiltered
                                     userInfo:@{NSLocalizedDescriptionKey: @"Value did not match predicate"}];
    return [self filter:predicate error:error];
}

- (PKFuture *)filter:(BOOL (^)(id _Nullable))predicate error:(NSError *)error {
    return [PKFuture futureWithResolver:^(void (^fulfill)(id _Nullable), void (^reject)(NSError *)) {
        [self addCallback:^(id _Nullable value, NSError * _Nullable err) {
            if (err) {
                reject(err);
            } else {
                if (predicate(value)) {
                    fulfill(value);
                } else {
                    reject(error);
                }
            }
        }];
    }];
}

// MARK: - Timing

- (PKFuture *)timeout:(NSTimeInterval)timeout {
    NSError *error = [NSError errorWithDomain:PKFutureErrorDomain
                                         code:PKFutureErrorTimeout
                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Future timed out after %.2f seconds", timeout]}];
    return [self timeout:timeout error:error];
}

- (PKFuture *)timeout:(NSTimeInterval)timeout error:(NSError *)error {
    return [PKFuture futureWithResolver:^(void (^fulfill)(id _Nullable), void (^reject)(NSError *)) {
        __block BOOL completed = NO;

        [self addCallback:^(id _Nullable value, NSError * _Nullable err) {
            @synchronized (self) {
                if (!completed) {
                    completed = YES;
                    if (err) {
                        reject(err);
                    } else {
                        fulfill(value);
                    }
                }
            }
        }];

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeout * NSEC_PER_SEC)),
                      dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            @synchronized (self) {
                if (!completed) {
                    completed = YES;
                    reject(error);
                }
            }
        });
    }];
}

- (PKFuture *)delay:(NSTimeInterval)delay {
    return [PKFuture futureWithResolver:^(void (^fulfill)(id _Nullable), void (^reject)(NSError *)) {
        [self addCallback:^(id _Nullable value, NSError * _Nullable error) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                          dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                if (error) {
                    reject(error);
                } else {
                    fulfill(value);
                }
            });
        }];
    }];
}

// MARK: - Composition

+ (PKFuture<NSArray *> *)all:(NSArray<PKFuture *> *)futures {
    if (futures.count == 0) {
        return [PKFuture fulfilledWithValue:@[]];
    }

    return [PKFuture futureWithResolver:^(void (^fulfill)(NSArray *), void (^reject)(NSError *)) {
        NSMutableArray *results = [NSMutableArray arrayWithCapacity:futures.count];
        for (NSUInteger i = 0; i < futures.count; i++) {
            [results addObject:[NSNull null]];
        }

        __block NSUInteger completedCount = 0;
        __block BOOL rejected = NO;

        for (NSUInteger i = 0; i < futures.count; i++) {
            PKFuture *future = futures[i];
            [future addCallback:^(id _Nullable value, NSError * _Nullable error) {
                @synchronized (results) {
                    if (rejected) return;

                    if (error) {
                        rejected = YES;
                        reject(error);
                    } else {
                        results[i] = value ?: [NSNull null];
                        completedCount++;

                        if (completedCount == futures.count) {
                            fulfill([results copy]);
                        }
                    }
                }
            }];
        }
    }];
}

+ (PKFuture *)any:(NSArray<PKFuture *> *)futures {
    if (futures.count == 0) {
        NSError *error = [NSError errorWithDomain:PKFutureErrorDomain
                                             code:PKFutureErrorNoValue
                                         userInfo:@{NSLocalizedDescriptionKey: @"No futures provided"}];
        return [PKFuture rejectedWithError:error];
    }

    return [PKFuture futureWithResolver:^(void (^fulfill)(id _Nullable), void (^reject)(NSError *)) {
        __block BOOL completed = NO;

        for (PKFuture *future in futures) {
            [future addCallback:^(id _Nullable value, NSError * _Nullable error) {
                @synchronized (futures) {
                    if (!completed && !error) {
                        completed = YES;
                        fulfill(value);
                    }
                }
            }];
        }
    }];
}

+ (PKFuture *)race:(NSArray<PKFuture *> *)futures {
    if (futures.count == 0) {
        NSError *error = [NSError errorWithDomain:PKFutureErrorDomain
                                             code:PKFutureErrorNoValue
                                         userInfo:@{NSLocalizedDescriptionKey: @"No futures provided"}];
        return [PKFuture rejectedWithError:error];
    }

    return [PKFuture futureWithResolver:^(void (^fulfill)(id _Nullable), void (^reject)(NSError *)) {
        __block BOOL completed = NO;

        for (PKFuture *future in futures) {
            [future addCallback:^(id _Nullable value, NSError * _Nullable error) {
                @synchronized (futures) {
                    if (!completed) {
                        completed = YES;
                        if (error) {
                            reject(error);
                        } else {
                            fulfill(value);
                        }
                    }
                }
            }];
        }
    }];
}

+ (PKFuture<NSArray *> *)sequence:(NSArray<PKFuture * (^)(void)> *)futures {
    if (futures.count == 0) {
        return [PKFuture fulfilledWithValue:@[]];
    }

    return [PKFuture futureWithResolver:^(void (^fulfill)(NSArray *), void (^reject)(NSError *)) {
        NSMutableArray *results = [NSMutableArray array];
        __block NSUInteger index = 0;

        void (^executeNext)(void) = ^void(void) {};
        __block void (^executeNextBlock)(void) = ^{
            if (index >= futures.count) {
                fulfill([results copy]);
                return;
            }

            PKFuture * (^creator)(void) = futures[index];
            index++;

            PKFuture *future = creator();
            [future addCallback:^(id _Nullable value, NSError * _Nullable error) {
                if (error) {
                    reject(error);
                } else {
                    [results addObject:value ?: [NSNull null]];
                    executeNextBlock();
                }
            }];
        };

        executeNext = executeNextBlock;
        executeNextBlock();
    }];
}

// MARK: - Iteration

+ (PKFuture *)whileTrue:(BOOL (^)(void))condition do:(PKFuture * (^)(void))operation {
    return [PKFuture futureWithResolver:^(void (^fulfill)(id _Nullable), void (^reject)(NSError *)) {
        void (^iterate)(void) = ^void(void) {};
        __block void (^iterateBlock)(void) = ^{
            if (!condition()) {
                fulfill(nil);
                return;
            }

            PKFuture *future = operation();
            [future addCallback:^(id _Nullable value, NSError * _Nullable error) {
                if (error) {
                    reject(error);
                } else {
                    iterateBlock();
                }
            }];
        };

        iterate = iterateBlock;
        iterateBlock();
    }];
}

+ (PKFuture *)while:(BOOL (^)(id _Nullable))condition
                 do:(PKFuture * (^)(id _Nullable))operation
            initial:(nullable id)initial {
    return [PKFuture futureWithResolver:^(void (^fulfill)(id _Nullable), void (^reject)(NSError *)) {
        __block id accumulated = initial;

        void (^iterate)(void) = ^void(void) {};
        __block void (^iterateBlock)(void) = ^{
            if (!condition(accumulated)) {
                fulfill(accumulated);
                return;
            }

            PKFuture *future = operation(accumulated);
            [future addCallback:^(id _Nullable value, NSError * _Nullable error) {
                if (error) {
                    reject(error);
                } else {
                    accumulated = value;
                    iterateBlock();
                }
            }];
        };

        iterate = iterateBlock;
        iterateBlock();
    }];
}

+ (PKFuture *)repeat:(NSUInteger)count do:(PKFuture * (^)(NSUInteger))operation {
    return [PKFuture futureWithResolver:^(void (^fulfill)(id _Nullable), void (^reject)(NSError *)) {
        __block NSUInteger iteration = 0;

        void (^iterate)(void) = ^void(void) {};
        __block void (^iterateBlock)(void) = ^{
            if (iteration >= count) {
                fulfill(@(iteration));
                return;
            }

            PKFuture *future = operation(iteration);
            iteration++;

            [future addCallback:^(id _Nullable value, NSError * _Nullable error) {
                if (error) {
                    reject(error);
                } else {
                    iterateBlock();
                }
            }];
        };

        iterate = iterateBlock;
        iterateBlock();
    }];
}

+ (PKFuture<NSArray *> *)forEach:(NSArray *)items do:(PKFuture * (^)(id, NSUInteger))operation {
    if (items.count == 0) {
        return [PKFuture fulfilledWithValue:@[]];
    }

    return [PKFuture futureWithResolver:^(void (^fulfill)(NSArray *), void (^reject)(NSError *)) {
        NSMutableArray *results = [NSMutableArray array];
        __block NSUInteger index = 0;

        void (^iterate)(void) = ^void(void) {};
        __block void (^iterateBlock)(void) = ^{
            if (index >= items.count) {
                fulfill([results copy]);
                return;
            }

            id item = items[index];
            NSUInteger currentIndex = index;
            index++;

            PKFuture *future = operation(item, currentIndex);
            [future addCallback:^(id _Nullable value, NSError * _Nullable error) {
                if (error) {
                    reject(error);
                } else {
                    [results addObject:value ?: [NSNull null]];
                    iterateBlock();
                }
            }];
        };

        iterate = iterateBlock;
        iterateBlock();
    }];
}

// MARK: - Synchronization

- (nullable id)waitWithTimeout:(NSTimeInterval)timeout error:(NSError **)error {
    if (self.state != PKFutureStatePending) {
        if (error && self.error) {
            *error = self.error;
        }
        return self.value;
    }

    dispatch_time_t waitTime = timeout > 0
        ? dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeout * NSEC_PER_SEC))
        : DISPATCH_TIME_FOREVER;

    long result = dispatch_semaphore_wait(self.semaphore, waitTime);

    if (result != 0) {
        if (error) {
            *error = [NSError errorWithDomain:PKFutureErrorDomain
                                         code:PKFutureErrorTimeout
                                     userInfo:@{NSLocalizedDescriptionKey: @"Wait timed out"}];
        }
        return nil;
    }

    if (error && self.error) {
        *error = self.error;
    }

    return self.value;
}

- (nullable id)wait {
    return [self waitWithTimeout:0 error:nil];
}

- (NSString *)description {
    NSString *stateStr = @"pending";
    if (self.state == PKFutureStateFulfilled) {
        stateStr = @"fulfilled";
    } else if (self.state == PKFutureStateRejected) {
        stateStr = @"rejected";
    }

    return [NSString stringWithFormat:@"<PKFuture: %@ - %@>", stateStr,
            self.value ?: self.error ?: @"(pending)"];
}

@end

// MARK: - Convenience

@implementation PKFuture (Convenience)

+ (PKFuture *)after:(NSTimeInterval)delay value:(nullable id)value {
    return [PKFuture futureWithResolver:^(void (^fulfill)(id _Nullable), void (^reject)(NSError *)) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                      dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            fulfill(value);
        });
    }];
}

+ (PKFuture *)fromBlock:(id _Nullable (^)(void))block {
    return [PKFuture futureWithResolver:^(void (^fulfill)(id _Nullable), void (^reject)(NSError *)) {
        @try {
            id result = block();
            fulfill(result);
        } @catch (NSException *exception) {
            NSError *error = [NSError errorWithDomain:PKFutureErrorDomain
                                                 code:PKFutureErrorInvalidState
                                             userInfo:@{NSLocalizedDescriptionKey: exception.reason ?: @"Block execution failed"}];
            reject(error);
        }
    }];
}

+ (PKFuture *)fromAsync:(void (^)(void (^)(id _Nullable, NSError * _Nullable)))operation {
    return [PKFuture futureWithResolver:^(void (^fulfill)(id _Nullable), void (^reject)(NSError *)) {
        operation(^(id _Nullable value, NSError * _Nullable error) {
            if (error) {
                reject(error);
            } else {
                fulfill(value);
            }
        });
    }];
}

- (PKFuture<NSArray *> *)zip:(PKFuture *)other {
    return [PKFuture futureWithResolver:^(void (^fulfill)(NSArray *), void (^reject)(NSError *)) {
        __block id value1 = nil;
        __block id value2 = nil;
        __block BOOL completed1 = NO;
        __block BOOL completed2 = NO;
        __block BOOL failed = NO;

        [self addCallback:^(id _Nullable value, NSError * _Nullable error) {
            @synchronized (self) {
                if (failed) return;

                if (error) {
                    failed = YES;
                    reject(error);
                } else {
                    value1 = value ?: [NSNull null];
                    completed1 = YES;

                    if (completed2) {
                        fulfill(@[value1, value2]);
                    }
                }
            }
        }];

        [other addCallback:^(id _Nullable value, NSError * _Nullable error) {
            @synchronized (self) {
                if (failed) return;

                if (error) {
                    failed = YES;
                    reject(error);
                } else {
                    value2 = value ?: [NSNull null];
                    completed2 = YES;

                    if (completed1) {
                        fulfill(@[value1, value2]);
                    }
                }
            }
        }];
    }];
}

@end
