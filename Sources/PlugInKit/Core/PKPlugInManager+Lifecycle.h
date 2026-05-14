//
//  PKPlugInManager+Lifecycle.h
//  PlugInKit
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PKPlugInManager.h"

NS_ASSUME_NONNULL_BEGIN

/// Default drain timeout used by `suspendPlugIn:completion:`.
FOUNDATION_EXPORT const NSTimeInterval PKLifecycleDefaultSuspendDrainTimeout;

/// Lifecycle management for the plugin manager.
///
/// Drives the optional `PKPlugInProtocol` lifecycle hooks
/// (`willLoad`/`didLoad`/`willUnload`/`didUnload`/`willSuspend`/`didResume`) and
/// exposes host-level suspend/resume control over individual plugins.
@interface PKPlugInManager (Lifecycle)

/// When YES, the manager suspends all connected plugins on
/// `NSWorkspaceWillSleepNotification` and resumes them on
/// `NSWorkspaceDidWakeNotification`. Default: NO.
@property (nonatomic, assign) BOOL suspendOnSystemSleep;

/// Suspend a connected plugin using the default drain timeout.
/// @param identifier Plugin identifier
/// @param completion Completion handler; receives an error if the connection
///   could not be suspended, or `PKErrorOperationTimedOut` if in-flight
///   operations did not drain (the plugin is suspended regardless).
- (void)suspendPlugIn:(NSString *)identifier
           completion:(nullable void (^)(NSError * _Nullable error))completion;

/// Suspend a connected plugin, waiting up to `drainTimeout` for in-flight work.
/// @param identifier Plugin identifier
/// @param drainTimeout Seconds to wait for tracked in-flight operations to drain
/// @param completion Completion handler
- (void)suspendPlugIn:(NSString *)identifier
     withDrainTimeout:(NSTimeInterval)drainTimeout
           completion:(nullable void (^)(NSError * _Nullable error))completion;

/// Resume a previously suspended plugin.
/// @param identifier Plugin identifier
/// @param completion Completion handler
- (void)resumePlugIn:(NSString *)identifier
          completion:(nullable void (^)(NSError * _Nullable error))completion;

@end

/// Delegate protocol for plugin lifecycle notifications.
@protocol PKPlugInManagerLifecycleDelegate <NSObject>

@optional

/// Called before a plugin's `initializeWithConfiguration:reply:` runs.
- (void)plugInManager:(PKPlugInManager *)manager willLoadPlugIn:(NSString *)identifier;

/// Called after a plugin connection is fully established.
- (void)plugInManager:(PKPlugInManager *)manager didLoadPlugIn:(NSString *)identifier;

/// Called before a plugin connection is torn down.
- (void)plugInManager:(PKPlugInManager *)manager willUnloadPlugIn:(NSString *)identifier;

/// Called after a plugin connection has been torn down.
- (void)plugInManager:(PKPlugInManager *)manager didUnloadPlugIn:(NSString *)identifier;

/// Called after the plugin's willSuspend hook completes (the plugin is now suspended).
- (void)plugInManager:(PKPlugInManager *)manager willSuspendPlugIn:(NSString *)identifier;

/// Called after the plugin's didResume hook completes (the plugin is now active).
- (void)plugInManager:(PKPlugInManager *)manager didResumePlugIn:(NSString *)identifier;

@end

NS_ASSUME_NONNULL_END
