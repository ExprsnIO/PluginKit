//
//  PKPlugInManager+Dependencies.h
//  PlugInKit
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PKPlugInManager.h"

@class PKCancellationToken;

NS_ASSUME_NONNULL_BEGIN

/// Dependency resolution and ordered connection for the plugin manager.
///
/// Plugins declare dependencies via the `PKRequiredPlugins` Info.plist key (see
/// `PKPlugInDependency`). Resolution is ordering-only: a dependency is connected
/// before any plugin that requires it. Plugins do not share an XPC transport.
@interface PKPlugInManager (Dependencies)

/// Compute a connection order for the given plugins, including their transitive
/// required dependencies, such that every dependency precedes its dependents.
///
/// @param identifiers Plugin identifiers to order (must already be discovered)
/// @param error On failure, set to `PKErrorCircularDependency`,
///   `PKErrorMissingDependency`, or `PKErrorDependencyVersionMismatch`.
///   `PKErrorCircularDependency` includes the cycle in `PKErrorDependencyChainKey`.
/// @return An ordered array of identifiers, or nil on failure
- (nullable NSArray<NSString *> *)loadOrderForPlugIns:(NSArray<NSString *> *)identifiers
                                                error:(NSError **)error;

/// Discover all plugins and connect them in dependency order.
///
/// Connections are attempted sequentially in resolved order. A failure to
/// connect one plugin is recorded but does not abort the remaining connections.
///
/// @param completion Called with the successfully connected plugins keyed by
///   identifier, and an array of any errors encountered (including a resolution
///   error if the dependency graph could not be ordered).
- (void)connectAllWithDependencyResolutionWithCompletion:
    (void (^)(NSDictionary<NSString *, PKConnection *> *connected,
              NSArray<NSError *> *errors))completion;

/// Discover all plugins and connect them in dependency order, abortable via a
/// cancellation token.
///
/// @param token Optional cancellation token; checked before each connection
/// @param completion Called with connected plugins and any errors. If the token
///   is cancelled mid-resolution, an `PKErrorOperationCancelled` error is
///   included and remaining connections are skipped.
- (void)connectAllWithDependencyResolutionCancellationToken:(nullable PKCancellationToken *)token
                                                 completion:
    (void (^)(NSDictionary<NSString *, PKConnection *> *connected,
              NSArray<NSError *> *errors))completion;

@end

/// Delegate protocol for dependency resolution notifications.
@protocol PKPlugInManagerDependencyDelegate <NSObject>

@optional

/// Called before a plugin is connected because another plugin requires it.
/// @param manager Plugin manager
/// @param identifier The dependency being connected
/// @param dependentIdentifier The plugin that requires it
- (void)plugInManager:(PKPlugInManager *)manager
    willConnectPlugIn:(NSString *)identifier
    becauseRequiredBy:(NSString *)dependentIdentifier;

/// Called when an optional dependency is skipped during resolution.
/// @param manager Plugin manager
/// @param identifier The optional dependency that was skipped
/// @param reason Human-readable reason for skipping
- (void)plugInManager:(PKPlugInManager *)manager
didSkipOptionalDependency:(NSString *)identifier
               reason:(NSString *)reason;

@end

NS_ASSUME_NONNULL_END
