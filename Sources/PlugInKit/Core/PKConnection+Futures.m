//
//  PKConnection+Futures.m
//  PlugInKit
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

#import "PKConnection+Futures.h"
#import "../Futures/PKFuture.h"
#import "../../PlugInKitProtocol/PKPlugInProtocol.h"
#import "../../PlugInKitProtocol/PKPlugInProtocol+Futures.h"

@implementation PKConnection (Futures)

- (PKFuture<NSDictionary *> *)pollFuture {
    return [PKFuture futureWithResolver:^(void (^fulfill)(NSDictionary *), void (^reject)(NSError *)) {
        [self pollWithCompletion:^(BOOL success, NSTimeInterval latency, NSError * _Nullable error) {
            if (error) {
                reject(error);
            } else {
                fulfill(@{
                    @"success": @(success),
                    @"latency": @(latency),
                    @"health": @(self.health),
                    @"averageLatency": @(self.averageLatency)
                });
            }
        }];
    }];
}

- (PKFuture *)executeWithPlugin:(PKFuture * (^)(id<PKPlugInProtocol>))operation {
    return [PKFuture futureWithResolver:^(void (^fulfill)(id _Nullable), void (^reject)(NSError *)) {
        id<PKPlugInProtocol> plugin = [self remotePlugInWithErrorHandler:^(NSError *error) {
            reject(error);
        }];

        PKFuture *operationFuture = operation(plugin);
        [operationFuture onComplete:^(id _Nullable value, NSError * _Nullable error) {
            if (error) {
                reject(error);
            } else {
                fulfill(value);
            }
        }];
    }];
}

- (PKFuture<NSNull *> *)initializePluginWithConfiguration:(NSDictionary<NSString *, id> *)configuration {
    return [PKFuture futureWithResolver:^(void (^fulfill)(NSNull *), void (^reject)(NSError *)) {
        id<PKPlugInProtocol> plugin = [self remotePlugInWithErrorHandler:^(NSError *error) {
            reject(error);
        }];

        // Try future-based first
        if ([plugin respondsToSelector:@selector(initializeWithConfigurationFuture:)]) {
            id<PKPlugInProtocolFutures> futurePlugin = (id<PKPlugInProtocolFutures>)plugin;
            PKFuture<NSNull *> *future = [futurePlugin initializeWithConfigurationFuture:configuration];
            [future onComplete:^(NSNull * _Nullable value, NSError * _Nullable error) {
                if (error) {
                    reject(error);
                } else {
                    fulfill(value);
                }
            }];
        } else {
            // Fallback to callback-based
            [plugin initializeWithConfiguration:configuration reply:^(NSError * _Nullable error) {
                if (error) {
                    reject(error);
                } else {
                    fulfill([NSNull null]);
                }
            }];
        }
    }];
}

- (PKFuture<NSArray<PKMethodMetadata *> *> *)getExposedMethods {
    return [PKFuture futureWithResolver:^(void (^fulfill)(NSArray<PKMethodMetadata *> *), void (^reject)(NSError *)) {
        id<PKPlugInProtocol> plugin = [self remotePlugInWithErrorHandler:^(NSError *error) {
            reject(error);
        }];

        // Try future-based first
        if ([plugin respondsToSelector:@selector(exposedMethodsFuture)]) {
            id<PKPlugInProtocolFutures> futurePlugin = (id<PKPlugInProtocolFutures>)plugin;
            PKFuture<NSArray<PKMethodMetadata *> *> *future = [futurePlugin exposedMethodsFuture];
            [future onComplete:^(NSArray<PKMethodMetadata *> * _Nullable value, NSError * _Nullable error) {
                if (error) {
                    reject(error);
                } else {
                    fulfill(value);
                }
            }];
        } else {
            // Fallback to callback-based
            [plugin exposedMethodsWithReply:^(NSArray<PKMethodMetadata *> * _Nonnull methods) {
                fulfill(methods);
            }];
        }
    }];
}

- (PKFuture<NSDictionary<NSString *, id> *> *)getCapabilities {
    return [PKFuture futureWithResolver:^(void (^fulfill)(NSDictionary<NSString *, id> *), void (^reject)(NSError *)) {
        id<PKPlugInProtocol> plugin = [self remotePlugInWithErrorHandler:^(NSError *error) {
            reject(error);
        }];

        if (![plugin respondsToSelector:@selector(capabilitiesWithReply:)] &&
            ![plugin respondsToSelector:@selector(capabilitiesFuture)]) {
            fulfill(@{});
            return;
        }

        // Try future-based first
        if ([plugin respondsToSelector:@selector(capabilitiesFuture)]) {
            id<PKPlugInProtocolFutures> futurePlugin = (id<PKPlugInProtocolFutures>)plugin;
            PKFuture<NSDictionary<NSString *, id> *> *future = [futurePlugin capabilitiesFuture];
            [future onComplete:^(NSDictionary<NSString *, id> * _Nullable value, NSError * _Nullable error) {
                if (error) {
                    reject(error);
                } else {
                    fulfill(value ?: @{});
                }
            }];
        } else {
            // Fallback to callback-based
            [plugin capabilitiesWithReply:^(NSDictionary<NSString *,id> * _Nonnull capabilities) {
                fulfill(capabilities);
            }];
        }
    }];
}

- (PKFuture<NSDictionary<NSString *, id> *> *)sendMessage:(NSDictionary<NSString *, id> *)message {
    return [PKFuture futureWithResolver:^(void (^fulfill)(NSDictionary<NSString *, id> *), void (^reject)(NSError *)) {
        id<PKPlugInProtocol> plugin = [self remotePlugInWithErrorHandler:^(NSError *error) {
            reject(error);
        }];

        if (![plugin respondsToSelector:@selector(handleMessage:reply:)] &&
            ![plugin respondsToSelector:@selector(handleMessageFuture:)]) {
            NSError *error = [NSError errorWithDomain:@"com.pluginkit.connection"
                                                 code:1
                                             userInfo:@{NSLocalizedDescriptionKey: @"Plugin does not support messages"}];
            reject(error);
            return;
        }

        // Try future-based first
        if ([plugin respondsToSelector:@selector(handleMessageFuture:)]) {
            id<PKPlugInProtocolFutures> futurePlugin = (id<PKPlugInProtocolFutures>)plugin;
            PKFuture<NSDictionary<NSString *, id> *> *future = [futurePlugin handleMessageFuture:message];
            [future onComplete:^(NSDictionary<NSString *, id> * _Nullable value, NSError * _Nullable error) {
                if (error) {
                    reject(error);
                } else {
                    fulfill(value ?: @{});
                }
            }];
        } else {
            // Fallback to callback-based
            [plugin handleMessage:message reply:^(NSDictionary<NSString *,id> * _Nullable response, NSError * _Nullable error) {
                if (error) {
                    reject(error);
                } else {
                    fulfill(response ?: @{});
                }
            }];
        }
    }];
}

- (PKFuture<NSNull *> *)prepareForTermination {
    return [PKFuture futureWithResolver:^(void (^fulfill)(NSNull *), void (^reject)(NSError *)) {
        id<PKPlugInProtocol> plugin = [self remotePlugInWithErrorHandler:^(NSError *error) {
            reject(error);
        }];

        // Try future-based first
        if ([plugin respondsToSelector:@selector(prepareForTerminationFuture)]) {
            id<PKPlugInProtocolFutures> futurePlugin = (id<PKPlugInProtocolFutures>)plugin;
            PKFuture<NSNull *> *future = [futurePlugin prepareForTerminationFuture];
            [future onComplete:^(NSNull * _Nullable value, NSError * _Nullable error) {
                if (error) {
                    reject(error);
                } else {
                    fulfill(value);
                }
            }];
        } else {
            // Fallback to callback-based
            [plugin prepareForTerminationWithReply:^{
                fulfill([NSNull null]);
            }];
        }
    }];
}

- (PKFuture *)retry:(PKFuture * (^)(void))operation maxAttempts:(NSUInteger)maxAttempts {
    return [PKFuture futureWithResolver:^(void (^fulfill)(id _Nullable), void (^reject)(NSError *)) {
        __block NSUInteger attempt = 0;

        void (^tryOperation)(void) = ^void(void) {};
        __block void (^tryOperationBlock)(void) = ^{
            attempt++;

            PKFuture *future = operation();
            [future onComplete:^(id _Nullable value, NSError * _Nullable error) {
                if (error) {
                    if (attempt < maxAttempts) {
                        // Exponential backoff
                        NSTimeInterval delay = pow(2.0, attempt - 1);
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                                      dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                            tryOperationBlock();
                        });
                    } else {
                        reject(error);
                    }
                } else {
                    fulfill(value);
                }
            }];
        };

        tryOperation = tryOperationBlock;
        tryOperationBlock();
    }];
}

- (PKFuture *)execute:(PKFuture * (^)(void))operation timeout:(NSTimeInterval)timeout {
    PKFuture *future = operation();
    return [future timeout:timeout];
}

@end
