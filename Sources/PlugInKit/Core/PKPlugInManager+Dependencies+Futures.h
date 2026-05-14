//
//  PKPlugInManager+Dependencies+Futures.h
//  PlugInKit
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PKPlugInManager+Dependencies.h"

@class PKFuture;
@class PKCancellationToken;

NS_ASSUME_NONNULL_BEGIN

/// Futures-based variant of dependency-ordered connection.
@interface PKPlugInManager (DependenciesFutures)

/// Discover all plugins and connect them in dependency order.
/// @return A future that fulfills with the connected plugins keyed by
///   identifier. It rejects only if no plugins could be connected and at least
///   one error occurred; partial success fulfills with the connected subset.
- (PKFuture<NSDictionary<NSString *, PKConnection *> *> *)connectAllWithDependencyResolutionFuture;

/// Discover and connect all plugins in dependency order, abortable via a token.
/// @param token Optional cancellation token
/// @return A future as described in `connectAllWithDependencyResolutionFuture`.
- (PKFuture<NSDictionary<NSString *, PKConnection *> *> *)
    connectAllWithDependencyResolutionFutureCancellationToken:(nullable PKCancellationToken *)token;

@end

NS_ASSUME_NONNULL_END
