//
//  PKFuture+Progress.h
//  PlugInKit
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PKFuture.h"

NS_ASSUME_NONNULL_BEGIN

@interface PKFuture (Progress)

/// Progress object for tracking operation progress
@property (nonatomic, strong, readonly, nullable) NSProgress *progress;

/// Attach a progress object to this future
/// @param progress Progress instance to attach
/// @return Same future for chaining
- (PKFuture *)withProgress:(NSProgress *)progress;

/// Report progress updates via callback
/// @param progressHandler Block called with progress updates
/// @return Same future for chaining
- (PKFuture *)reportProgress:(void (^)(NSProgress *progress))progressHandler;

/// Create a future with progress reporting
/// @param resolver Resolver block that receives progress object
+ (instancetype)futureWithProgress:(void (^)(void (^fulfill)(id _Nullable value),
                                              void (^reject)(NSError *error),
                                              NSProgress *progress))resolver;

/// Create a future with progress and total unit count
/// @param totalUnitCount Total units of work
/// @param resolver Resolver block
+ (instancetype)futureWithTotalUnitCount:(int64_t)totalUnitCount
                                resolver:(void (^)(void (^fulfill)(id _Nullable value),
                                                   void (^reject)(NSError *error),
                                                   NSProgress *progress))resolver;

@end

NS_ASSUME_NONNULL_END
