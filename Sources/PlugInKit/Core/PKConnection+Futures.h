//
//  PKConnection+Futures.h
//  PlugInKit
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

#import "PKConnection.h"

@class PKFuture;

NS_ASSUME_NONNULL_BEGIN

/// Future-based extensions for PKConnection
@interface PKConnection (Futures)

/// Poll the connection using futures
/// @return Future with poll result dictionary @{@"success": @(BOOL), @"latency": @(NSTimeInterval)}
- (PKFuture<NSDictionary *> *)pollFuture;

/// Get remote plugin proxy and execute operation
/// @param operation Block to execute with plugin
/// @return Future with operation result
- (PKFuture *)executeWithPlugin:(PKFuture * (^)(id<PKPlugInProtocol> plugin))operation;

/// Initialize plugin with futures
/// @param configuration Configuration dictionary
/// @return Future that completes when initialization is done
- (PKFuture<NSNull *> *)initializePluginWithConfiguration:(NSDictionary<NSString *, id> *)configuration;

/// Get exposed methods using futures
/// @return Future with array of method metadata
- (PKFuture<NSArray<PKMethodMetadata *> *> *)getExposedMethods;

/// Get plugin capabilities using futures
/// @return Future with capabilities dictionary
- (PKFuture<NSDictionary<NSString *, id> *> *)getCapabilities;

/// Send message to plugin using futures
/// @param message Message dictionary
/// @return Future with response
- (PKFuture<NSDictionary<NSString *, id> *> *)sendMessage:(NSDictionary<NSString *, id> *)message;

/// Prepare plugin for termination using futures
/// @return Future that completes when plugin is ready to terminate
- (PKFuture<NSNull *> *)prepareForTermination;

/// Retry an operation with exponential backoff
/// @param operation Operation to retry
/// @param maxAttempts Maximum number of attempts
/// @return Future with eventual result
- (PKFuture *)retry:(PKFuture * (^)(void))operation maxAttempts:(NSUInteger)maxAttempts;

/// Execute operation with timeout
/// @param operation Operation to execute
/// @param timeout Timeout in seconds
/// @return Future with result or timeout error
- (PKFuture *)execute:(PKFuture * (^)(void))operation timeout:(NSTimeInterval)timeout;

@end

NS_ASSUME_NONNULL_END
