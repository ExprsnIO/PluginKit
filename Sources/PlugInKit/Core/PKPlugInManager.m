//
//  PKPlugInManager.m
//  PlugInKit
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

#import "PKPlugInManager.h"
#import "PKPlugInManager+Lifecycle.h"
#import "../../PlugInKitProtocol/PKPlugInProtocol.h"
#import "../../PlugInKitProtocol/PKHostProtocol.h"

@implementation PKPlugInInfo

- (instancetype)initWithIdentifier:(NSString *)identifier
                              name:(NSString *)name
                           version:(NSString *)version
                         bundleURL:(NSURL *)bundleURL
                       serviceName:(NSString *)serviceName {
    if (self = [super init]) {
        _identifier = [identifier copy];
        _name = [name copy];
        _version = [version copy];
        _bundleURL = [bundleURL copy];
        _serviceName = [serviceName copy];
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<PKPlugInInfo: %@ (%@) v%@>",
            self.name, self.identifier, self.version];
}

- (BOOL)isEqual:(id)object {
    if (self == object) return YES;
    if (![object isKindOfClass:[PKPlugInInfo class]]) return NO;

    PKPlugInInfo *other = (PKPlugInInfo *)object;
    return [self.identifier isEqualToString:other.identifier];
}

- (NSUInteger)hash {
    return self.identifier.hash;
}

@end

@interface PKPlugInManager () <PKConnectionDelegate>

@property (nonatomic, strong) NSMutableDictionary<NSString *, PKPlugInInfo *> *plugInRegistry;
@property (nonatomic, strong) NSMutableDictionary<NSString *, PKConnection *> *connections;
@property (nonatomic, strong) dispatch_queue_t managerQueue;
@property (nonatomic, strong) NSXPCInterface *plugInInterface;
@property (nonatomic, strong) NSXPCInterface *hostInterface;

@end

@implementation PKPlugInManager

+ (instancetype)sharedManager {
    static PKPlugInManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    if (self = [super init]) {
        _plugInRegistry = [NSMutableDictionary dictionary];
        _connections = [NSMutableDictionary dictionary];
        _managerQueue = dispatch_queue_create("com.pluginkit.manager", DISPATCH_QUEUE_CONCURRENT);
        _pollingEnabled = YES;
        _defaultPollingInterval = 5.0;

        // Configure XPC interfaces
        _plugInInterface = [NSXPCInterface interfaceWithProtocol:@protocol(PKPlugInProtocol)];
        _hostInterface = [NSXPCInterface interfaceWithProtocol:@protocol(PKHostProtocol)];

        // Configure allowed classes for method metadata
        NSSet *metadataClasses = [NSSet setWithObjects:[NSArray class], [PKMethodMetadata class], nil];
        [_plugInInterface setClasses:metadataClasses
                         forSelector:@selector(exposedMethodsWithReply:)
                       argumentIndex:0
                             ofReply:YES];
    }
    return self;
}

- (NSArray<PKPlugInInfo *> *)discoveredPlugIns {
    __block NSArray<PKPlugInInfo *> *result;
    dispatch_sync(self.managerQueue, ^{
        result = [self.plugInRegistry.allValues copy];
    });
    return result;
}

- (NSArray<PKConnection *> *)activeConnections {
    __block NSArray<PKConnection *> *result;
    dispatch_sync(self.managerQueue, ^{
        result = [self.connections.allValues copy];
    });
    return result;
}

- (void)discoverPlugInsWithCompletion:(nullable void (^)(NSArray<PKPlugInInfo *> *plugIns, NSError * _Nullable error))completion {
    // Discover in the main bundle's PlugIns directory
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSURL *plugInsURL = [mainBundle builtInPlugInsURL];

    if (!plugInsURL) {
        NSError *error = [NSError errorWithDomain:@"com.pluginkit.manager"
                                             code:1
                                         userInfo:@{NSLocalizedDescriptionKey: @"No PlugIns directory found"}];
        if (completion) {
            completion(@[], error);
        }
        return;
    }

    [self discoverPlugInsAtURL:plugInsURL completion:completion];
}

- (void)discoverPlugInsAtURL:(NSURL *)url
                  completion:(nullable void (^)(NSArray<PKPlugInInfo *> *plugIns, NSError * _Nullable error))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSError *error = nil;

        NSArray<NSURL *> *contents = [fileManager contentsOfDirectoryAtURL:url
                                                includingPropertiesForKeys:@[NSURLIsDirectoryKey]
                                                                   options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                     error:&error];

        if (error) {
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(@[], error);
                });
            }
            return;
        }

        NSMutableArray<PKPlugInInfo *> *discoveredPlugIns = [NSMutableArray array];

        for (NSURL *plugInURL in contents) {
            if (![plugInURL.pathExtension isEqualToString:@"bundle"]) {
                continue;
            }

            NSBundle *plugInBundle = [NSBundle bundleWithURL:plugInURL];
            if (!plugInBundle) {
                continue;
            }

            NSDictionary *info = plugInBundle.infoDictionary;
            NSString *identifier = info[@"CFBundleIdentifier"];
            NSString *name = info[@"CFBundleName"] ?: plugInURL.lastPathComponent.stringByDeletingPathExtension;
            NSString *version = info[@"CFBundleShortVersionString"] ?: @"1.0";
            NSString *serviceName = info[@"PKXPCServiceName"];

            if (!identifier || !serviceName) {
                NSLog(@"Skipping plugin at %@: missing identifier or service name", plugInURL);
                continue;
            }

            PKPlugInInfo *plugInInfo = [[PKPlugInInfo alloc] initWithIdentifier:identifier
                                                                            name:name
                                                                         version:version
                                                                       bundleURL:plugInURL
                                                                     serviceName:serviceName];

            dispatch_barrier_async(self.managerQueue, ^{
                self.plugInRegistry[identifier] = plugInInfo;
            });

            [discoveredPlugIns addObject:plugInInfo];

            // Notify delegate
            if ([self.delegate respondsToSelector:@selector(plugInManager:didDiscoverPlugIn:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate plugInManager:self didDiscoverPlugIn:plugInInfo];
                });
            }
        }

        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion([discoveredPlugIns copy], nil);
            });
        }
    });
}

- (void)connectToPlugIn:(NSString *)identifier
          configuration:(nullable NSDictionary<NSString *, id> *)configuration
             completion:(void (^)(PKConnection * _Nullable connection, NSError * _Nullable error))completion {
    __block PKPlugInInfo *plugInInfo = nil;

    dispatch_sync(self.managerQueue, ^{
        plugInInfo = self.plugInRegistry[identifier];
    });

    if (!plugInInfo) {
        NSError *error = [NSError errorWithDomain:@"com.pluginkit.manager"
                                             code:2
                                         userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Plugin not found: %@", identifier]}];
        if (completion) {
            completion(nil, error);
        }
        return;
    }

    // Check if already connected
    __block PKConnection *existingConnection = nil;
    dispatch_sync(self.managerQueue, ^{
        existingConnection = self.connections[identifier];
    });

    if (existingConnection) {
        if (completion) {
            completion(existingConnection, nil);
        }
        return;
    }

    // Create new connection
    PKConnection *connection = [[PKConnection alloc] initWithPlugInIdentifier:identifier
                                                                  serviceName:plugInInfo.serviceName
                                                                    interface:self.plugInInterface];
    connection.delegate = self;
    connection.pollingEnabled = self.pollingEnabled;
    connection.pollingInterval = self.defaultPollingInterval;

    dispatch_barrier_async(self.managerQueue, ^{
        self.connections[identifier] = connection;
    });

    [connection start];

    // Initialize the plugin
    id<PKPlugInProtocol> plugin = [connection remotePlugInWithErrorHandler:^(NSError *error) {
        dispatch_barrier_async(self.managerQueue, ^{
            [self.connections removeObjectForKey:identifier];
        });

        if ([self.delegate respondsToSelector:@selector(plugInManager:didFailToConnectToPlugIn:error:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate plugInManager:self didFailToConnectToPlugIn:identifier error:error];
            });
        }

        if (completion) {
            completion(nil, error);
        }
    }];

    NSDictionary *config = configuration ?: @{};

    // Lifecycle hook: didLoad runs after a successful initialization.
    void (^finishLoad)(void) = ^{
        id<PKPlugInManagerLifecycleDelegate> lifecycleDelegate = self.lifecycleDelegate;
        if ([lifecycleDelegate respondsToSelector:@selector(plugInManager:didLoadPlugIn:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [lifecycleDelegate plugInManager:self didLoadPlugIn:identifier];
            });
        }

        if ([self.delegate respondsToSelector:@selector(plugInManager:didEstablishConnection:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate plugInManager:self didEstablishConnection:connection];
            });
        }

        if (completion) {
            completion(connection, nil);
        }
    };

    void (^proceedToInitialize)(void) = ^{
        [plugin initializeWithConfiguration:config reply:^(NSError * _Nullable error) {
            if (error) {
                dispatch_barrier_async(self.managerQueue, ^{
                    [self.connections removeObjectForKey:identifier];
                });

                if ([self.delegate respondsToSelector:@selector(plugInManager:didFailToConnectToPlugIn:error:)]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate plugInManager:self didFailToConnectToPlugIn:identifier error:error];
                    });
                }

                if (completion) {
                    completion(nil, error);
                }
                return;
            }

            if ([plugin respondsToSelector:@selector(didLoadWithReply:)]) {
                [plugin didLoadWithReply:^(NSError * _Nullable loadError) {
                    finishLoad();
                }];
            } else {
                finishLoad();
            }
        }];
    };

    // Lifecycle hook: willLoad runs before initialization.
    id<PKPlugInManagerLifecycleDelegate> lifecycleDelegate = self.lifecycleDelegate;
    if ([lifecycleDelegate respondsToSelector:@selector(plugInManager:willLoadPlugIn:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [lifecycleDelegate plugInManager:self willLoadPlugIn:identifier];
        });
    }

    if ([plugin respondsToSelector:@selector(willLoadWithReply:)]) {
        [plugin willLoadWithReply:^(NSError * _Nullable error) {
            proceedToInitialize();
        }];
    } else {
        proceedToInitialize();
    }
}

- (void)disconnectFromPlugIn:(NSString *)identifier {
    __block PKConnection *connection = nil;

    dispatch_barrier_sync(self.managerQueue, ^{
        connection = self.connections[identifier];
        [self.connections removeObjectForKey:identifier];
    });

    if (!connection) {
        return;
    }

    id<PKPlugInManagerLifecycleDelegate> lifecycleDelegate = self.lifecycleDelegate;
    if ([lifecycleDelegate respondsToSelector:@selector(plugInManager:willUnloadPlugIn:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [lifecycleDelegate plugInManager:self willUnloadPlugIn:identifier];
        });
    }

    id<PKPlugInProtocol> plugin = [connection synchronousRemotePlugInWithErrorHandler:^(NSError *error) {
        NSLog(@"Error disconnecting from plugin %@: %@", identifier, error);
    }];

    // Lifecycle hooks bracket termination while the connection is still live.
    if ([plugin respondsToSelector:@selector(willUnloadWithReply:)]) {
        [plugin willUnloadWithReply:^(NSError * _Nullable error) {}];
    }

    [plugin prepareForTerminationWithReply:^{}];

    if ([plugin respondsToSelector:@selector(didUnloadWithReply:)]) {
        [plugin didUnloadWithReply:^(NSError * _Nullable error) {}];
    }

    [connection stop];

    if ([lifecycleDelegate respondsToSelector:@selector(plugInManager:didUnloadPlugIn:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [lifecycleDelegate plugInManager:self didUnloadPlugIn:identifier];
        });
    }

    if ([self.delegate respondsToSelector:@selector(plugInManager:didRemovePlugIn:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate plugInManager:self didRemovePlugIn:identifier];
        });
    }
}

- (nullable PKConnection *)connectionForPlugIn:(NSString *)identifier {
    __block PKConnection *connection = nil;
    dispatch_sync(self.managerQueue, ^{
        connection = self.connections[identifier];
    });
    return connection;
}

- (nullable PKPlugInInfo *)plugInInfoForIdentifier:(NSString *)identifier {
    __block PKPlugInInfo *info = nil;
    dispatch_sync(self.managerQueue, ^{
        info = self.plugInRegistry[identifier];
    });
    return info;
}

- (void)broadcastMessage:(NSDictionary<NSString *, id> *)message
              completion:(nullable void (^)(NSDictionary<NSString *, id> *responses))completion {
    __block NSArray<PKConnection *> *currentConnections = nil;

    dispatch_sync(self.managerQueue, ^{
        currentConnections = [self.connections.allValues copy];
    });

    if (currentConnections.count == 0) {
        if (completion) {
            completion(@{});
        }
        return;
    }

    NSMutableDictionary<NSString *, id> *responses = [NSMutableDictionary dictionary];
    dispatch_group_t group = dispatch_group_create();

    for (PKConnection *connection in currentConnections) {
        dispatch_group_enter(group);

        id<PKPlugInProtocol> plugin = [connection remotePlugInWithErrorHandler:^(NSError *error) {
            @synchronized (responses) {
                responses[connection.plugInIdentifier] = error;
            }
            dispatch_group_leave(group);
        }];

        if ([plugin respondsToSelector:@selector(handleMessage:reply:)]) {
            [plugin handleMessage:message reply:^(NSDictionary<NSString *,id> * _Nullable response, NSError * _Nullable error) {
                @synchronized (responses) {
                    responses[connection.plugInIdentifier] = response ?: error;
                }
                dispatch_group_leave(group);
            }];
        } else {
            dispatch_group_leave(group);
        }
    }

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        if (completion) {
            completion([responses copy]);
        }
    });
}

#pragma mark - PKConnectionDelegate

- (void)connection:(PKConnection *)connection didChangeHealth:(PKConnectionHealth)health {
    // Forward to interested parties
    NSLog(@"Plugin %@ health changed to %ld", connection.plugInIdentifier, (long)health);
}

- (void)connection:(PKConnection *)connection didChangeState:(PKXPCConnectionState)state {
    NSLog(@"Plugin %@ state changed to %ld", connection.plugInIdentifier, (long)state);
}

@end
