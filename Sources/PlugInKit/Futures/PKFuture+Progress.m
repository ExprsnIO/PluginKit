//
//  PKFuture+Progress.m
//  PlugInKit
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

#import "PKFuture+Progress.h"
#import <objc/runtime.h>

static const void *PKFutureProgressKey = &PKFutureProgressKey;
static const void *PKFutureProgressHandlersKey = &PKFutureProgressHandlersKey;

@implementation PKFuture (Progress)

- (NSProgress *)progress {
    return objc_getAssociatedObject(self, PKFutureProgressKey);
}

- (void)setProgress:(NSProgress *)progress {
    objc_setAssociatedObject(self, PKFutureProgressKey, progress, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // Notify any registered handlers
    NSArray *handlers = objc_getAssociatedObject(self, PKFutureProgressHandlersKey);
    for (void (^handler)(NSProgress *) in handlers) {
        handler(progress);
    }
}

- (PKFuture *)withProgress:(NSProgress *)progress {
    [self setProgress:progress];
    return self;
}

- (PKFuture *)reportProgress:(void (^)(NSProgress *progress))progressHandler {
    if (!progressHandler) {
        return self;
    }

    // Get or create handlers array
    NSMutableArray *handlers = objc_getAssociatedObject(self, PKFutureProgressHandlersKey);
    if (!handlers) {
        handlers = [NSMutableArray array];
        objc_setAssociatedObject(self, PKFutureProgressHandlersKey, handlers, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    [handlers addObject:[progressHandler copy]];

    // If progress already exists, call handler immediately
    NSProgress *currentProgress = self.progress;
    if (currentProgress) {
        progressHandler(currentProgress);
    }

    return self;
}

+ (instancetype)futureWithProgress:(void (^)(void (^fulfill)(id _Nullable value),
                                              void (^reject)(NSError *error),
                                              NSProgress *progress))resolver {
    NSProgress *progress = [NSProgress progressWithTotalUnitCount:100];

    PKFuture *future = [self futureWithResolver:^(void (^fulfill)(id _Nullable value),
                                                   void (^reject)(NSError *error)) {
        resolver(fulfill, reject, progress);
    }];

    [future setProgress:progress];

    // Mark progress as complete when future completes
    [future onComplete:^(id _Nullable value, NSError * _Nullable error) {
        if (progress.completedUnitCount < progress.totalUnitCount) {
            progress.completedUnitCount = progress.totalUnitCount;
        }
    }];

    return future;
}

+ (instancetype)futureWithTotalUnitCount:(int64_t)totalUnitCount
                                resolver:(void (^)(void (^fulfill)(id _Nullable value),
                                                   void (^reject)(NSError *error),
                                                   NSProgress *progress))resolver {
    NSProgress *progress = [NSProgress progressWithTotalUnitCount:totalUnitCount];

    PKFuture *future = [self futureWithResolver:^(void (^fulfill)(id _Nullable value),
                                                   void (^reject)(NSError *error)) {
        resolver(fulfill, reject, progress);
    }];

    [future setProgress:progress];

    // Mark progress as complete when future completes
    [future onComplete:^(id _Nullable value, NSError * _Nullable error) {
        if (progress.completedUnitCount < progress.totalUnitCount) {
            progress.completedUnitCount = progress.totalUnitCount;
        }
    }];

    return future;
}

@end
