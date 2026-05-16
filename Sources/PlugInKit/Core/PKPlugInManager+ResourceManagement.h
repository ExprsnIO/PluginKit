//
//  PKPlugInManager+ResourceManagement.h
//  PlugInKit
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PKPlugInManager.h"

NS_ASSUME_NONNULL_BEGIN

/// Configured resource limits for a plugin.
@interface PKResourceLimits : NSObject

/// Memory limit in bytes, or 0 for no limit.
@property (nonatomic, assign, readonly) size_t memoryLimit;

/// CPU limit as a percentage (0-100+), or 0 for no limit.
@property (nonatomic, assign, readonly) double cpuLimit;

- (instancetype)initWithMemoryLimit:(size_t)memoryLimit cpuLimit:(double)cpuLimit;

@end

/// Resource monitoring and quota enforcement for connected plugins.
///
/// A single background timer samples each connected plugin's XPC service
/// process via `proc_pid_rusage`. When a plugin exceeds a configured memory or
/// CPU limit, the resource delegate is notified; if the limit stays exceeded
/// for three consecutive samples the plugin is automatically disconnected.
@interface PKPlugInManager (ResourceManagement)

/// Interval between resource samples, in seconds. Default: 5.0.
/// Setting this restarts the monitor if it is running.
@property (nonatomic, assign) NSTimeInterval resourceMonitoringInterval;

/// Set a memory limit for a plugin. Pass 0 to remove the limit.
/// @param bytes Memory limit in bytes
/// @param identifier Plugin identifier
- (void)setMemoryLimit:(size_t)bytes forPlugIn:(NSString *)identifier;

/// Set a CPU limit for a plugin. Pass 0 to remove the limit.
/// @param percentage CPU limit as a percentage (e.g. 80.0)
/// @param identifier Plugin identifier
- (void)setCPULimit:(double)percentage forPlugIn:(NSString *)identifier;

/// The configured resource limits for a plugin, or nil if none are set.
/// @param identifier Plugin identifier
- (nullable PKResourceLimits *)resourceLimitsForPlugIn:(NSString *)identifier;

/// The most recently sampled physical memory footprint of a plugin, in bytes.
/// Returns 0 if the plugin is not connected or has not been sampled yet.
/// @param identifier Plugin identifier
- (size_t)memoryUsageForPlugIn:(NSString *)identifier;

/// The most recently sampled CPU usage of a plugin, as a percentage.
/// Returns 0 if the plugin is not connected or has not been sampled yet.
/// @param identifier Plugin identifier
- (double)cpuUsageForPlugIn:(NSString *)identifier;

@end

/// Delegate protocol for resource management notifications.
@protocol PKPlugInManagerResourceDelegate <NSObject>

@optional

/// Called when a plugin's memory usage exceeds its configured limit.
/// @param manager Plugin manager
/// @param identifier Plugin identifier
/// @param currentBytes Current physical footprint in bytes
/// @param limitBytes Configured memory limit in bytes
- (void)plugInManager:(PKPlugInManager *)manager
       plugIn:(NSString *)identifier
 didExceedMemoryLimit:(size_t)limitBytes
              current:(size_t)currentBytes;

/// Called when a plugin's CPU usage exceeds its configured limit.
/// @param manager Plugin manager
/// @param identifier Plugin identifier
/// @param currentPercentage Current CPU usage percentage
/// @param limitPercentage Configured CPU limit percentage
- (void)plugInManager:(PKPlugInManager *)manager
       plugIn:(NSString *)identifier
    didExceedCPULimit:(double)limitPercentage
              current:(double)currentPercentage;

/// Called when a plugin is automatically disconnected for staying over a limit.
/// @param manager Plugin manager
/// @param identifier Plugin identifier
/// @param error The resource error that triggered the disconnect
- (void)plugInManager:(PKPlugInManager *)manager
didDisconnectPlugInForResourceViolation:(NSString *)identifier
                error:(NSError *)error;

@end

NS_ASSUME_NONNULL_END
