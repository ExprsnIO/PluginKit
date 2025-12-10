//
//  PKFuture+Cancellation.m
//  PlugInKit
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

#import "PKFuture+Cancellation.h"
#import <objc/runtime.h>

static const void *PKFutureCancellationTokenKey = &PKFutureCancellationTokenKey;

// Import the error domain from PKError if available, otherwise define locally
#ifndef PKErrorDomain
FOUNDATION_EXPORT NSErrorDomain const PKErrorDomain = @"com.pluginkit.error";
#endif

typedef NS_ENUM(NSInteger, PKError) {
    PKErrorOperationCancelled = 1700
};

@implementation PKFuture (Cancellation)

- (PKCancellationToken *)cancellationToken {
    PKCancellationToken *token = objc_getAssociatedObject(self, PKFutureCancellationTokenKey);
    if (!token) {
        token = [[PKCancellationToken alloc] init];
        objc_setAssociatedObject(self, PKFutureCancellationTokenKey, token, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return token;
}

- (void)cancel {
    [self.cancellationToken cancel];

    // If future is still pending, reject it with cancellation error
    if (self.state == PKFutureStatePending) {
        NSError *error = [NSError errorWithDomain:PKErrorDomain
                                             code:PKErrorOperationCancelled
                                         userInfo:@{
                                             NSLocalizedDescriptionKey: @"Operation was cancelled"
                                         }];

        // The future's internal rejection will handle the state transition
        // We use KVC to access the private rejection mechanism
        SEL selector = NSSelectorFromString(@"rejectWithError:");
        if ([self respondsToSelector:selector]) {
            IMP imp = [self methodForSelector:selector];
            void (*func)(id, SEL, NSError *) = (void *)imp;
            func(self, selector, error);
        }
    }
}

- (PKFuture *)attachCancellationToken:(PKCancellationToken *)token {
    // Create a new future that completes with this future but can be cancelled
    return [PKFuture futureWithResolver:^(void (^fulfill)(id _Nullable value),
                                          void (^reject)(NSError *error),
                                          PKCancellationToken *futureToken) {

        // Link the provided token to the new future's token
        [token onCancelled:^{
            [futureToken cancel];
        }];

        // When this future completes, complete the new future
        [self onComplete:^(id _Nullable value, NSError * _Nullable error) {
            if (!futureToken.isCancelled) {
                if (error) {
                    reject(error);
                } else {
                    fulfill(value);
                }
            }
        }];
    } cancellationToken:token];
}

- (PKFuture *)onCancelled:(void (^)(void))handler {
    [self.cancellationToken onCancelled:handler];
    return self;
}

+ (instancetype)futureWithResolver:(void (^)(void (^fulfill)(id _Nullable value),
                                             void (^reject)(NSError *error),
                                             PKCancellationToken *token))resolver
                 cancellationToken:(PKCancellationToken *)token {

    PKFuture *future = [self futureWithResolver:^(void (^fulfill)(id _Nullable value),
                                                   void (^reject)(NSError *error)) {
        resolver(fulfill, reject, token);
    }];

    // Associate the token with the future
    objc_setAssociatedObject(future, PKFutureCancellationTokenKey, token, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // Auto-reject if token is already cancelled
    if (token.isCancelled) {
        [future cancel];
    }

    return future;
}

@end
