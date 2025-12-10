//
//  PKPlugInManager+HotReload.h
//  PlugInKit
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PKPlugInManager.h"

NS_ASSUME_NONNULL_BEGIN

/// State of a plugin reload operation
typedef NS_ENUM(NSInteger, PKReloadState) {
    PKReloadStateIdle,
    PKReloadStatePreparing,
    PKReloadStateMigratingState,
    PKReloadStateReloading,
    PKReloadStateCompleted,
    PKReloadStateFailed,
    PKReloadStateRolledBack
};

/// Options for hot-reload behavior
typedef NS_OPTIONS(NSUInteger, PKReloadOptions) {
    PKReloadOptionsNone                  = 0,
    PKReloadOptionsPreserveState         = 1 << 0,  ///< Attempt to preserve plugin state
    PKReloadOptionsAllowDowngrade        = 1 << 1,  ///< Allow reloading with older version
    PKReloadOptionsRollbackOnFailure     = 1 << 2,  ///< Rollback to previous version on error
    PKReloadOptionsNotifyClients         = 1 << 3,  ///< Notify connected clients of reload
    PKReloadOptionsDefault = PKReloadOptionsPreserveState | PKReloadOptionsRollbackOnFailure | PKReloadOptionsNotifyClients
};

/// Hot-reload capability for plugin manager
@interface PKPlugInManager (HotReload)

/// Whether hot-reload is enabled globally (default: NO)
@property (nonatomic, assign, getter=isHotReloadEnabled) BOOL hotReloadEnabled;

/// Whether to automatically watch for plugin updates (default: NO)
@property (nonatomic, assign) BOOL automaticReloadEnabled;

/// Interval for checking plugin updates in seconds (default: 30.0)
@property (nonatomic, assign) NSTimeInterval reloadCheckInterval;

/// Reload a specific plugin
/// @param identifier Plugin identifier
/// @param options Reload options
/// @param completion Completion handler
- (void)reloadPlugIn:(NSString *)identifier
             options:(PKReloadOptions)options
          completion:(void (^)(BOOL success, NSError * _Nullable error))completion;

/// Reload a plugin with state migration
/// @param identifier Plugin identifier
/// @param stateMigrationHandler Block to migrate state from old to new instance
/// @param completion Completion handler
- (void)reloadPlugIn:(NSString *)identifier
withStateMigration:(nullable NSDictionary * (^)(NSDictionary *oldState))stateMigrationHandler
          completion:(void (^)(BOOL success, NSError * _Nullable error))completion;

/// Check if a plugin has updates available
/// @param identifier Plugin identifier
/// @param completion Completion handler with update availability
- (void)checkForUpdates:(NSString *)identifier
             completion:(void (^)(BOOL hasUpdate, NSString * _Nullable newVersion))completion;

/// Get current reload state for a plugin
/// @param identifier Plugin identifier
/// @return Current reload state
- (PKReloadState)reloadStateForPlugIn:(NSString *)identifier;

/// Cancel an in-progress reload
/// @param identifier Plugin identifier
- (void)cancelReload:(NSString *)identifier;

@end

/// Delegate protocol for hot-reload notifications
@protocol PKPlugInManagerHotReloadDelegate <NSObject>

@optional

/// Called when a plugin reload is about to begin
/// @param manager Plugin manager
/// @param plugIn Plugin being reloaded
- (void)plugInManager:(PKPlugInManager *)manager willReloadPlugIn:(PKPlugInInfo *)plugIn;

/// Called when a plugin reload completes successfully
/// @param manager Plugin manager
/// @param plugIn Plugin that was reloaded
/// @param oldVersion Previous version
/// @param newVersion New version
- (void)plugInManager:(PKPlugInManager *)manager
       didReloadPlugIn:(PKPlugInInfo *)plugIn
           fromVersion:(NSString *)oldVersion
             toVersion:(NSString *)newVersion;

/// Called when a plugin reload fails
/// @param manager Plugin manager
/// @param plugIn Plugin that failed to reload
/// @param error Error that occurred
- (void)plugInManager:(PKPlugInManager *)manager
didFailToReloadPlugIn:(PKPlugInInfo *)plugIn
                error:(NSError *)error;

/// Called when an update is detected
/// @param manager Plugin manager
/// @param plugIn Plugin with available update
/// @param newVersion New version available
- (void)plugInManager:(PKPlugInManager *)manager
     didDetectUpdate:(PKPlugInInfo *)plugIn
          newVersion:(NSString *)newVersion;

/// Called to request permission to reload
/// @param manager Plugin manager
/// @param plugIn Plugin requesting reload
/// @param completion Completion handler to grant/deny permission
- (void)plugInManager:(PKPlugInManager *)manager
requestReloadPermissionForPlugIn:(PKPlugInInfo *)plugIn
           completion:(void (^)(BOOL granted))completion;

@end

NS_ASSUME_NONNULL_END
