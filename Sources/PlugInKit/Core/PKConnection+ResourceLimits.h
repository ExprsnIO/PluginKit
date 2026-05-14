//
//  PKConnection+ResourceLimits.h
//  PlugInKit
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PKConnection.h"

@protocol PKPlugInProtocol;

NS_ASSUME_NONNULL_BEGIN

/// Per-connection resource governance.
///
/// Provides opt-in throttling for operations issued against a plugin: a
/// concurrency cap, a bounded pending queue, and a per-operation timeout.
/// Callers that want governance route work through
/// `performGovernedOperation:completion:` instead of using the raw proxy
/// returned by `remotePlugInWithErrorHandler:`.
@interface PKConnection (ResourceLimits)

/// Maximum number of governed operations allowed to run concurrently.
/// Default: `NSUIntegerMax` (unlimited).
@property (nonatomic, assign) NSUInteger maxConcurrentOperations;

/// Timeout applied to each governed operation, in seconds.
/// Default: `0` (no timeout).
@property (nonatomic, assign) NSTimeInterval operationTimeout;

/// Maximum number of governed operations allowed to wait for a concurrency
/// slot. Operations submitted while the queue is full fail immediately with
/// `PKErrorQueueFull`. Default: `NSUIntegerMax` (unlimited).
@property (nonatomic, assign) NSUInteger maxQueuedMessages;

/// Number of governed operations currently waiting for a concurrency slot.
@property (nonatomic, assign, readonly) NSUInteger currentQueueDepth;

/// Perform a resource-governed operation against the remote plugin.
///
/// The operation block receives the remote plugin proxy and a `done` block it
/// MUST invoke exactly once when the operation finishes. The call honors
/// `maxConcurrentOperations`, `maxQueuedMessages`, `operationTimeout`, and
/// connection suspension.
///
/// @param operationBlock Block performing the work; must call `done` when finished
/// @param completion Completion handler; receives `nil` on success,
///   `PKErrorPlugInSuspended` if the connection is suspended,
///   `PKErrorQueueFull` if the pending queue is full, or
///   `PKErrorOperationTimedOut` if the operation exceeded `operationTimeout`.
- (void)performGovernedOperation:(void (^)(id<PKPlugInProtocol> plugin, void (^done)(void)))operationBlock
                      completion:(nullable void (^)(NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
