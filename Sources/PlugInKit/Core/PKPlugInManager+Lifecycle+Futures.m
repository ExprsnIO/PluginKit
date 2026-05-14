//
//  PKPlugInManager+Lifecycle+Futures.m
//  PlugInKit
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

#import "PKPlugInManager+Lifecycle+Futures.h"
#import "PKFuture.h"

@implementation PKPlugInManager (LifecycleFutures)

- (PKFuture<NSNull *> *)suspendPlugInFuture:(NSString *)identifier {
    return [PKFuture futureWithResolver:^(void (^fulfill)(id _Nullable),
                                          void (^reject)(NSError *)) {
        [self suspendPlugIn:identifier completion:^(NSError * _Nullable error) {
            if (error) {
                reject(error);
            } else {
                fulfill([NSNull null]);
            }
        }];
    }];
}

- (PKFuture<NSNull *> *)resumePlugInFuture:(NSString *)identifier {
    return [PKFuture futureWithResolver:^(void (^fulfill)(id _Nullable),
                                          void (^reject)(NSError *)) {
        [self resumePlugIn:identifier completion:^(NSError * _Nullable error) {
            if (error) {
                reject(error);
            } else {
                fulfill([NSNull null]);
            }
        }];
    }];
}

@end
