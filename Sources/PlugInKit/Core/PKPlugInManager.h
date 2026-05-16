//
//  PKPlugInManager.h
//  PlugInKit
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PKConnection.h"

NS_ASSUME_NONNULL_BEGIN

@class PKPlugInManager;
@protocol PKPlugInProtocol;

// Delegate protocols for manager categories. Declared here because Objective-C
// categories cannot add stored properties; the backing properties live on the
// base class while the behavior lives in the respective category.
@protocol PKPlugInManagerLifecycleDelegate;
@protocol PKPlugInManagerResourceDelegate;
@protocol PKPlugInManagerDependencyDelegate;

/// Plugin discovery info
@interface PKPlugInInfo : NSObject

@property (nonatomic, copy, readonly) NSString *identifier;
@property (nonatomic, copy, readonly) NSString *name;
@property (nonatomic, copy, readonly) NSString *version;
@property (nonatomic, copy, readonly) NSURL *bundleURL;
@property (nonatomic, copy, readonly) NSString *serviceName;

- (instancetype)initWithIdentifier:(NSString *)identifier
                              name:(NSString *)name
                           version:(NSString *)version
                         bundleURL:(NSURL *)bundleURL
                       serviceName:(NSString *)serviceName;

@end

/// Delegate protocol for plugin manager events
@protocol PKPlugInManagerDelegate <NSObject>

@optional

/// Called when a plugin is discovered
/// @param manager The plugin manager
/// @param plugInInfo Information about the discovered plugin
- (void)plugInManager:(PKPlugInManager *)manager didDiscoverPlugIn:(PKPlugInInfo *)plugInInfo;

/// Called when a plugin connection is established
/// @param manager The plugin manager
/// @param connection The established connection
- (void)plugInManager:(PKPlugInManager *)manager didEstablishConnection:(PKConnection *)connection;

/// Called when a plugin connection fails
/// @param manager The plugin manager
/// @param identifier Plugin identifier
/// @param error Error that occurred
- (void)plugInManager:(PKPlugInManager *)manager
didFailToConnectToPlugIn:(NSString *)identifier
                error:(NSError *)error;

/// Called when a plugin is removed
/// @param manager The plugin manager
/// @param identifier Plugin identifier
- (void)plugInManager:(PKPlugInManager *)manager didRemovePlugIn:(NSString *)identifier;

@end

/// Manager for discovering and managing plugin connections
@interface PKPlugInManager : NSObject

/// Shared instance
@property (class, nonatomic, readonly) PKPlugInManager *sharedManager;

/// Delegate for manager events
@property (nonatomic, weak, nullable) id<PKPlugInManagerDelegate> delegate;

/// Delegate for plugin lifecycle events (see PKPlugInManager+Lifecycle.h)
@property (nonatomic, weak, nullable) id<PKPlugInManagerLifecycleDelegate> lifecycleDelegate;

/// Delegate for resource management events (see PKPlugInManager+ResourceManagement.h)
@property (nonatomic, weak, nullable) id<PKPlugInManagerResourceDelegate> resourceDelegate;

/// Delegate for dependency resolution events (see PKPlugInManager+Dependencies.h)
@property (nonatomic, weak, nullable) id<PKPlugInManagerDependencyDelegate> dependencyDelegate;

/// All discovered plugins
@property (nonatomic, copy, readonly) NSArray<PKPlugInInfo *> *discoveredPlugIns;

/// All active connections
@property (nonatomic, copy, readonly) NSArray<PKConnection *> *activeConnections;

/// Whether automatic discovery is enabled
@property (nonatomic, assign, getter=isAutoDiscoveryEnabled) BOOL autoDiscoveryEnabled;

/// Whether polling is enabled for all connections (default: YES)
@property (nonatomic, assign, getter=isPollingEnabled) BOOL pollingEnabled;

/// Default polling interval for new connections (default: 5.0)
@property (nonatomic, assign) NSTimeInterval defaultPollingInterval;

- (instancetype)init NS_DESIGNATED_INITIALIZER;

/// Discover plugins in the application's PlugIns directory
- (void)discoverPlugInsWithCompletion:(nullable void (^)(NSArray<PKPlugInInfo *> *plugIns, NSError * _Nullable error))completion;

/// Discover plugins at a specific URL
/// @param url Directory URL to search for plugins
/// @param completion Completion handler
- (void)discoverPlugInsAtURL:(NSURL *)url
                  completion:(nullable void (^)(NSArray<PKPlugInInfo *> *plugIns, NSError * _Nullable error))completion;

/// Connect to a specific plugin
/// @param identifier Plugin identifier
/// @param configuration Configuration dictionary
/// @param completion Completion handler with connection
- (void)connectToPlugIn:(NSString *)identifier
          configuration:(nullable NSDictionary<NSString *, id> *)configuration
             completion:(void (^)(PKConnection * _Nullable connection, NSError * _Nullable error))completion;

/// Disconnect from a plugin
/// @param identifier Plugin identifier
- (void)disconnectFromPlugIn:(NSString *)identifier;

/// Get connection for a plugin
/// @param identifier Plugin identifier
/// @return Connection or nil if not connected
- (nullable PKConnection *)connectionForPlugIn:(NSString *)identifier;

/// Get plugin info
/// @param identifier Plugin identifier
/// @return Plugin info or nil if not found
- (nullable PKPlugInInfo *)plugInInfoForIdentifier:(NSString *)identifier;

/// Send message to all connected plugins
/// @param message Message dictionary
/// @param completion Completion handler with responses
- (void)broadcastMessage:(NSDictionary<NSString *, id> *)message
              completion:(nullable void (^)(NSDictionary<NSString *, id> *responses))completion;

@end

NS_ASSUME_NONNULL_END
