//
//  PKPlugInManager+Dependencies+Futures.m
//  PlugInKit
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

#import "PKPlugInManager+Dependencies+Futures.h"
#import "PKFuture.h"

@implementation PKPlugInManager (DependenciesFutures)

- (PKFuture<NSDictionary<NSString *, PKConnection *> *> *)connectAllWithDependencyResolutionFuture {
    return [self connectAllWithDependencyResolutionFutureCancellationToken:nil];
}

- (PKFuture<NSDictionary<NSString *, PKConnection *> *> *)
    connectAllWithDependencyResolutionFutureCancellationToken:(nullable PKCancellationToken *)token {
    return [PKFuture futureWithResolver:^(void (^fulfill)(id _Nullable),
                                          void (^reject)(NSError *)) {
        [self connectAllWithDependencyResolutionCancellationToken:token
                                                       completion:^(NSDictionary<NSString *, PKConnection *> *connected,
                                                                    NSArray<NSError *> *errors) {
            if (connected.count == 0 && errors.count > 0) {
                reject(errors.firstObject);
            } else {
                fulfill(connected);
            }
        }];
    }];
}

@end
