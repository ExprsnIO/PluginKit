//
//  PKPlugInManager+Lifecycle+Futures.h
//  PlugInKit
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PKPlugInManager+Lifecycle.h"

@class PKFuture;

NS_ASSUME_NONNULL_BEGIN

/// Futures-based variants of the lifecycle suspend/resume APIs.
@interface PKPlugInManager (LifecycleFutures)

/// Suspend a plugin using the default drain timeout.
/// @param identifier Plugin identifier
/// @return A future that fulfills when the plugin is suspended, or rejects if
///   the connection could not be suspended (including a drain timeout).
- (PKFuture<NSNull *> *)suspendPlugInFuture:(NSString *)identifier;

/// Resume a previously suspended plugin.
/// @param identifier Plugin identifier
/// @return A future that fulfills when the plugin is resumed, or rejects on error.
- (PKFuture<NSNull *> *)resumePlugInFuture:(NSString *)identifier;

@end

NS_ASSUME_NONNULL_END
