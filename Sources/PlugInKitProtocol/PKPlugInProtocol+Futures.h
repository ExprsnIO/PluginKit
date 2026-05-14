//
//  PKPlugInProtocol+Futures.h
//  PlugInKit
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

#import "PKPlugInProtocol.h"

@class PKFuture;

NS_ASSUME_NONNULL_BEGIN

/// Future-based extensions for PKPlugInProtocol
@protocol PKPlugInProtocolFutures <PKPlugInProtocol>

@optional

/// Initialize the plugin with configuration (future-based)
/// @param configuration Dictionary containing plugin-specific configuration
/// @return Future that completes when initialization is done
- (PKFuture<NSNull *> *)initializeWithConfigurationFuture:(NSDictionary<NSString *, id> *)configuration;

/// Retrieve metadata for all exposed methods (future-based)
/// @return Future that completes with array of method metadata
- (PKFuture<NSArray<PKMethodMetadata *> *> *)exposedMethodsFuture;

/// Prepare for termination (future-based)
/// @return Future that completes when cleanup is done
- (PKFuture<NSNull *> *)prepareForTerminationFuture;

/// Handle custom messages from the host (future-based)
/// @param message Message dictionary
/// @return Future that completes with response
- (PKFuture<NSDictionary<NSString *, id> *> *)handleMessageFuture:(NSDictionary<NSString *, id> *)message;

/// Request for plugin-specific capabilities (future-based)
/// @return Future that completes with capabilities dictionary
- (PKFuture<NSDictionary<NSString *, id> *> *)capabilitiesFuture;

/// Lifecycle hook: about to load (future-based)
- (PKFuture<NSNull *> *)willLoadFuture;

/// Lifecycle hook: did load (future-based)
- (PKFuture<NSNull *> *)didLoadFuture;

/// Lifecycle hook: about to unload (future-based)
- (PKFuture<NSNull *> *)willUnloadFuture;

/// Lifecycle hook: did unload (future-based)
- (PKFuture<NSNull *> *)didUnloadFuture;

/// Lifecycle hook: about to suspend (future-based)
- (PKFuture<NSNull *> *)willSuspendFuture;

/// Lifecycle hook: did resume (future-based)
- (PKFuture<NSNull *> *)didResumeFuture;

/// Execute a remote procedure call
/// @param selector Method selector
/// @param arguments Array of arguments
/// @return Future with the result
- (PKFuture *)executeRPC:(NSString *)selector arguments:(NSArray *)arguments;

/// Execute multiple RPCs in parallel
/// @param calls Array of dictionaries with @{@"selector": ..., @"arguments": ...}
/// @return Future with array of results
- (PKFuture<NSArray *> *)executeRPCs:(NSArray<NSDictionary *> *)calls;

/// Execute RPCs sequentially
/// @param calls Array of dictionaries with @{@"selector": ..., @"arguments": ...}
/// @return Future with array of results
- (PKFuture<NSArray *> *)executeRPCsSequentially:(NSArray<NSDictionary *> *)calls;

@end

NS_ASSUME_NONNULL_END
