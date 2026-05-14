//
//  PKConnection.h
//  PlugInKit
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PKXPCService.h"

NS_ASSUME_NONNULL_BEGIN

@class PKConnection;
@protocol PKPlugInProtocol;

/// Health status of a plugin connection
typedef NS_ENUM(NSInteger, PKConnectionHealth) {
    PKConnectionHealthUnknown,
    PKConnectionHealthHealthy,
    PKConnectionHealthDegraded,
    PKConnectionHealthUnhealthy
};

/// Delegate protocol for connection events
@protocol PKConnectionDelegate <NSObject>

@optional

/// Called when connection health changes
/// @param connection The plugin connection
/// @param health New health status
- (void)connection:(PKConnection *)connection didChangeHealth:(PKConnectionHealth)health;

/// Called when connection state changes
/// @param connection The plugin connection
/// @param state New state
- (void)connection:(PKConnection *)connection didChangeState:(PKXPCConnectionState)state;

/// Called when a poll completes
/// @param connection The plugin connection
/// @param success Whether the poll succeeded
/// @param latency Response latency in seconds
- (void)connection:(PKConnection *)connection didCompletePoll:(BOOL)success latency:(NSTimeInterval)latency;

@end

/// Plugin connection with health monitoring and polling
@interface PKConnection : NSObject

/// Plugin identifier
@property (nonatomic, copy, readonly) NSString *plugInIdentifier;

/// Connection health status
@property (nonatomic, assign, readonly) PKConnectionHealth health;

/// Current connection state
@property (nonatomic, assign, readonly) PKXPCConnectionState state;

/// Delegate for connection events
@property (nonatomic, weak, nullable) id<PKConnectionDelegate> delegate;

/// Whether polling is enabled
@property (nonatomic, assign, getter=isPollingEnabled) BOOL pollingEnabled;

/// Polling interval in seconds (default: 5.0)
@property (nonatomic, assign) NSTimeInterval pollingInterval;

/// Maximum allowed latency before connection is considered degraded (default: 1.0 seconds)
@property (nonatomic, assign) NSTimeInterval degradedLatencyThreshold;

/// Maximum allowed latency before connection is considered unhealthy (default: 3.0 seconds)
@property (nonatomic, assign) NSTimeInterval unhealthyLatencyThreshold;

/// Average latency over recent polls
@property (nonatomic, assign, readonly) NSTimeInterval averageLatency;

/// Whether the connection is currently suspended
@property (nonatomic, assign, readonly, getter=isSuspended) BOOL suspended;

/// Number of operations currently in flight (tracked via begin/endOperation)
@property (nonatomic, assign, readonly) NSUInteger inFlightOperationCount;

/// PID of the remote plugin XPC service process, or 0 if not connected
@property (nonatomic, assign, readonly) pid_t remoteProcessIdentifier;

/// Initialize with plugin identifier and service name
/// @param plugInIdentifier Unique identifier for the plugin
/// @param serviceName XPC service name
/// @param interface Remote object interface
- (instancetype)initWithPlugInIdentifier:(NSString *)plugInIdentifier
                             serviceName:(NSString *)serviceName
                               interface:(NSXPCInterface *)interface NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

/// Start the connection
- (void)start;

/// Stop the connection
- (void)stop;

/// Manually trigger a health poll
/// @param completion Completion handler with poll result
- (void)pollWithCompletion:(void (^)(BOOL success, NSTimeInterval latency, NSError * _Nullable error))completion;

/// Suspend the connection, waiting for in-flight operations to drain.
///
/// Calls `willSuspendWithReply:` on the plugin (if implemented), waits up to
/// `drainTimeout` seconds for tracked in-flight operations to complete, then
/// transitions to `PKXPCConnectionStateSuspended`. The completion handler
/// receives `PKErrorOperationTimedOut` if the drain did not finish in time;
/// the connection is suspended regardless.
/// @param drainTimeout Seconds to wait for in-flight operations to drain
/// @param completion Completion handler called when the connection is suspended
- (void)suspendWithDrainTimeout:(NSTimeInterval)drainTimeout
                     completion:(void (^)(NSError * _Nullable error))completion;

/// Resume a previously suspended connection.
///
/// Calls `didResumeWithReply:` on the plugin (if implemented) and transitions
/// back to `PKXPCConnectionStateConnected`.
/// @param completion Completion handler called when the connection is resumed
- (void)resumeWithCompletion:(void (^)(NSError * _Nullable error))completion;

/// Register the start of a tracked operation. Used for in-flight accounting and
/// suspend draining. Must be balanced with `endOperation`.
- (void)beginOperation;

/// Register the completion of a tracked operation started with `beginOperation`.
- (void)endOperation;

/// Get the remote plugin proxy
/// @param errorHandler Error handler
/// @return Remote object conforming to PKPlugInProtocol
- (id<PKPlugInProtocol>)remotePlugInWithErrorHandler:(void (^)(NSError *error))errorHandler;

/// Get the synchronous remote plugin proxy
/// @param errorHandler Error handler
/// @return Synchronous remote object conforming to PKPlugInProtocol
- (id<PKPlugInProtocol>)synchronousRemotePlugInWithErrorHandler:(void (^)(NSError *error))errorHandler;

@end

NS_ASSUME_NONNULL_END
