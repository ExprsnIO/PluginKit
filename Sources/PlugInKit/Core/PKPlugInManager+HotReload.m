//
//  PKPlugInManager+HotReload.m
//  PlugInKit
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

#import "PKPlugInManager+HotReload.h"
#import "PKPlugInManager+Compatibility.h"
#import "PKConnection.h"
#import "PKError.h"
#import "PKLogger.h"
#import <objc/runtime.h>

// Associated object keys
static const void *PKHotReloadEnabledKey = &PKHotReloadEnabledKey;
static const void *PKAutomaticReloadEnabledKey = &PKAutomaticReloadEnabledKey;
static const void *PKReloadCheckIntervalKey = &PKReloadCheckIntervalKey;
static const void *PKReloadStatesKey = &PKReloadStatesKey;
static const void *PKReloadTimersKey = &PKReloadTimersKey;

@implementation PKPlugInManager (HotReload)

// MARK: - Properties

- (BOOL)isHotReloadEnabled {
    NSNumber *value = objc_getAssociatedObject(self, PKHotReloadEnabledKey);
    return value ? value.boolValue : NO;
}

- (void)setHotReloadEnabled:(BOOL)hotReloadEnabled {
    objc_setAssociatedObject(self, PKHotReloadEnabledKey, @(hotReloadEnabled), OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    if (hotReloadEnabled && self.automaticReloadEnabled) {
        [self startAutomaticReloadMonitoring];
    } else {
        [self stopAutomaticReloadMonitoring];
    }
}

- (BOOL)automaticReloadEnabled {
    NSNumber *value = objc_getAssociatedObject(self, PKAutomaticReloadEnabledKey);
    return value ? value.boolValue : NO;
}

- (void)setAutomaticReloadEnabled:(BOOL)automaticReloadEnabled {
    objc_setAssociatedObject(self, PKAutomaticReloadEnabledKey, @(automaticReloadEnabled), OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    if (automaticReloadEnabled && self.isHotReloadEnabled) {
        [self startAutomaticReloadMonitoring];
    } else {
        [self stopAutomaticReloadMonitoring];
    }
}

- (NSTimeInterval)reloadCheckInterval {
    NSNumber *value = objc_getAssociatedObject(self, PKReloadCheckIntervalKey);
    return value ? value.doubleValue : 30.0;
}

- (void)setReloadCheckInterval:(NSTimeInterval)reloadCheckInterval {
    objc_setAssociatedObject(self, PKReloadCheckIntervalKey, @(reloadCheckInterval), OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    if (self.automaticReloadEnabled) {
        [self stopAutomaticReloadMonitoring];
        [self startAutomaticReloadMonitoring];
    }
}

- (NSMutableDictionary<NSString *, NSNumber *> *)reloadStates {
    NSMutableDictionary *states = objc_getAssociatedObject(self, PKReloadStatesKey);
    if (!states) {
        states = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(self, PKReloadStatesKey, states, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return states;
}

- (NSMutableDictionary<NSString *, NSTimer *> *)reloadTimers {
    NSMutableDictionary *timers = objc_getAssociatedObject(self, PKReloadTimersKey);
    if (!timers) {
        timers = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(self, PKReloadTimersKey, timers, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return timers;
}

// MARK: - Reload Methods

- (void)reloadPlugIn:(NSString *)identifier
             options:(PKReloadOptions)options
          completion:(void (^)(BOOL success, NSError *error))completion {

    [self reloadPlugIn:identifier
    withStateMigration:^NSDictionary *(NSDictionary *oldState) {
        return oldState; // Default: preserve state as-is
    }
            completion:completion];
}

- (void)reloadPlugIn:(NSString *)identifier
withStateMigration:(NSDictionary * (^)(NSDictionary *oldState))stateMigrationHandler
          completion:(void (^)(BOOL success, NSError *error))completion {

    PKLogger *logger = [PKLogger loggerWithCategory:@"HotReload"];
    [logger info:@"[%@] Starting hot-reload", identifier];

    if (!self.isHotReloadEnabled) {
        NSError *error = [NSError pk_errorWithCode:PKErrorInvalidState
                                       description:@"Hot-reload is not enabled"];
        if (completion) completion(NO, error);
        return;
    }

    // Check current reload state
    PKReloadState currentState = [self reloadStateForPlugIn:identifier];
    if (currentState != PKReloadStateIdle && currentState != PKReloadStateCompleted && currentState != PKReloadStateFailed) {
        NSError *error = [NSError pk_errorWithCode:PKErrorReloadInProgress
                                       description:@"Reload is already in progress"];
        if (completion) completion(NO, error);
        return;
    }

    // Get current plugin info
    PKPlugInInfo *currentPlugIn = [self plugInInfoForIdentifier:identifier];
    if (!currentPlugIn) {
        NSError *error = [NSError pk_errorWithCode:PKErrorPlugInNotFound
                                       description:@"Plugin not found"];
        if (completion) completion(NO, error);
        return;
    }

    // Update state
    [self setReloadState:PKReloadStatePreparing forPlugIn:identifier];

    // Get existing connection
    PKConnection *existingConnection = [self connectionForPlugIn:identifier];
    NSString *oldVersion = currentPlugIn.version;

    // Notify delegate
    id delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(plugInManager:willReloadPlugIn:)]) {
        [(id<PKPlugInManagerHotReloadDelegate>)delegate plugInManager:self willReloadPlugIn:currentPlugIn];
    }

    // Step 1: Extract state if needed
    __block NSDictionary *savedState = nil;

    void (^extractStateAndContinue)(void) = ^{
        [self setReloadState:PKReloadStateMigratingState forPlugIn:identifier];

        if (existingConnection && stateMigrationHandler) {
            // Request state from plugin
            id<PKPlugInProtocol> plugin = [existingConnection remotePlugInWithErrorHandler:^(NSError *error) {
                [logger error:@"[%@] Failed to connect for state extraction: %@", identifier, error];
            }];

            // Get capabilities which may include state
            if ([plugin respondsToSelector:@selector(capabilitiesWithReply:)]) {
                [plugin capabilitiesWithReply:^(NSDictionary *capabilities) {
                    savedState = capabilities[@"state"];
                    if (stateMigrationHandler) {
                        savedState = stateMigrationHandler(savedState);
                    }
                    [self continueReloadForPlugIn:identifier
                                       savedState:savedState
                                       oldVersion:oldVersion
                                       completion:completion];
                }];
                return;
            }
        }

        // No state to preserve, continue
        [self continueReloadForPlugIn:identifier
                           savedState:nil
                           oldVersion:oldVersion
                           completion:completion];
    };

    extractStateAndContinue();
}

- (void)continueReloadForPlugIn:(NSString *)identifier
                     savedState:(NSDictionary *)savedState
                     oldVersion:(NSString *)oldVersion
                     completion:(void (^)(BOOL success, NSError *error))completion {

    PKLogger *logger = [PKLogger loggerWithCategory:@"HotReload"];

    // Step 2: Disconnect existing connection
    [self setReloadState:PKReloadStateReloading forPlugIn:identifier];
    [logger debug:@"[%@] Disconnecting old instance", identifier];
    [self disconnectFromPlugIn:identifier];

    // Step 3: Re-discover plugin (picks up new version)
    PKPlugInInfo *plugIn = [self plugInInfoForIdentifier:identifier];
    NSURL *bundleURL = plugIn.bundleURL;

    [logger debug:@"[%@] Re-discovering plugin at: %@", identifier, bundleURL];

    [self discoverPlugInsAtURL:bundleURL.URLByDeletingLastPathComponent
                    completion:^(NSArray<PKPlugInInfo *> *plugIns, NSError *error) {

        if (error) {
            [self setReloadState:PKReloadStateFailed forPlugIn:identifier];
            [logger error:@"[%@] Re-discovery failed: %@", identifier, error];

            NSError *reloadError = [NSError pk_errorWithCode:PKErrorReloadFailed
                                                 description:@"Failed to re-discover plugin"
                                             underlyingError:error];
            if (completion) completion(NO, reloadError);
            return;
        }

        // Find the plugin in results
        PKPlugInInfo *newPlugIn = nil;
        for (PKPlugInInfo *p in plugIns) {
            if ([p.identifier isEqualToString:identifier]) {
                newPlugIn = p;
                break;
            }
        }

        if (!newPlugIn) {
            [self setReloadState:PKReloadStateFailed forPlugIn:identifier];
            NSError *notFoundError = [NSError pk_errorWithCode:PKErrorPlugInNotFound
                                                    description:@"Plugin not found after re-discovery"];
            if (completion) completion(NO, notFoundError);
            return;
        }

        [logger info:@"[%@] Reloading from v%@ to v%@", identifier, oldVersion, newPlugIn.version];

        // Step 4: Check compatibility
        NSError *compatError = nil;
        if (![self isPlugInCompatible:newPlugIn error:&compatError]) {
            [self setReloadState:PKReloadStateFailed forPlugIn:identifier];
            [logger error:@"[%@] New version is incompatible: %@", identifier, compatError];

            if (completion) completion(NO, compatError);
            return;
        }

        // Step 5: Reconnect
        NSMutableDictionary *config = [NSMutableDictionary dictionary];
        if (savedState) {
            config[@"restoredState"] = savedState;
        }

        [self connectToPlugIn:identifier
                configuration:config
                   completion:^(PKConnection *connection, NSError *connectError) {

            if (connectError) {
                [self setReloadState:PKReloadStateFailed forPlugIn:identifier];
                [logger error:@"[%@] Reconnection failed: %@", identifier, connectError];

                NSError *reloadError = [NSError pk_errorWithCode:PKErrorReloadFailed
                                                     description:@"Failed to reconnect to reloaded plugin"
                                                 underlyingError:connectError];
                if (completion) completion(NO, reloadError);
                return;
            }

            // Success!
            [self setReloadState:PKReloadStateCompleted forPlugIn:identifier];
            [logger info:@"[%@] Hot-reload completed successfully", identifier];

            // Notify delegate
            id delegate = self.delegate;
            if ([delegate respondsToSelector:@selector(plugInManager:didReloadPlugIn:fromVersion:toVersion:)]) {
                [(id<PKPlugInManagerHotReloadDelegate>)delegate plugInManager:self
                                                              didReloadPlugIn:newPlugIn
                                                                  fromVersion:oldVersion
                                                                    toVersion:newPlugIn.version];
            }

            if (completion) completion(YES, nil);
        }];
    }];
}

- (void)checkForUpdates:(NSString *)identifier
             completion:(void (^)(BOOL hasUpdate, NSString *newVersion))completion {

    PKPlugInInfo *currentPlugIn = [self plugInInfoForIdentifier:identifier];
    if (!currentPlugIn) {
        if (completion) completion(NO, nil);
        return;
    }

    NSString *currentVersion = currentPlugIn.version;
    NSURL *bundleURL = currentPlugIn.bundleURL;

    // Re-read bundle to check for version changes
    NSBundle *bundle = [NSBundle bundleWithURL:bundleURL];
    [bundle load];

    NSString *newVersion = [bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];

    if (newVersion && ![newVersion isEqualToString:currentVersion]) {
        if (completion) completion(YES, newVersion);

        // Notify delegate
        id delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(plugInManager:didDetectUpdate:newVersion:)]) {
            [(id<PKPlugInManagerHotReloadDelegate>)delegate plugInManager:self
                                                          didDetectUpdate:currentPlugIn
                                                               newVersion:newVersion];
        }
    } else {
        if (completion) completion(NO, nil);
    }
}

- (PKReloadState)reloadStateForPlugIn:(NSString *)identifier {
    NSNumber *state = [self reloadStates][identifier];
    return state ? (PKReloadState)state.integerValue : PKReloadStateIdle;
}

- (void)setReloadState:(PKReloadState)state forPlugIn:(NSString *)identifier {
    [self reloadStates][identifier] = @(state);
}

- (void)cancelReload:(NSString *)identifier {
    PKReloadState state = [self reloadStateForPlugIn:identifier];
    if (state == PKReloadStateIdle || state == PKReloadStateCompleted || state == PKReloadStateFailed) {
        return; // Nothing to cancel
    }

    [self setReloadState:PKReloadStateFailed forPlugIn:identifier];

    PKLogger *logger = [PKLogger loggerWithCategory:@"HotReload"];
    [logger warning:@"[%@] Reload cancelled by user", identifier];
}

// MARK: - Automatic Monitoring

- (void)startAutomaticReloadMonitoring {
    for (PKPlugInInfo *plugIn in self.discoveredPlugIns) {
        [self startMonitoringPlugIn:plugIn.identifier];
    }
}

- (void)stopAutomaticReloadMonitoring {
    NSMutableDictionary *timers = [self reloadTimers];
    for (NSTimer *timer in timers.allValues) {
        [timer invalidate];
    }
    [timers removeAllObjects];
}

- (void)startMonitoringPlugIn:(NSString *)identifier {
    NSMutableDictionary *timers = [self reloadTimers];

    // Don't create duplicate timers
    if (timers[identifier]) {
        return;
    }

    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:self.reloadCheckInterval
                                                      repeats:YES
                                                        block:^(NSTimer *t) {
        [self checkForUpdates:identifier completion:^(BOOL hasUpdate, NSString *newVersion) {
            if (hasUpdate) {
                // Request permission from delegate
                id delegate = self.delegate;
                if ([delegate respondsToSelector:@selector(plugInManager:requestReloadPermissionForPlugIn:completion:)]) {
                    PKPlugInInfo *plugIn = [self plugInInfoForIdentifier:identifier];
                    [(id<PKPlugInManagerHotReloadDelegate>)delegate plugInManager:self
                                                  requestReloadPermissionForPlugIn:plugIn
                                                                        completion:^(BOOL granted) {
                        if (granted) {
                            [self reloadPlugIn:identifier options:PKReloadOptionsDefault completion:nil];
                        }
                    }];
                } else {
                    // Auto-reload if no delegate to ask
                    [self reloadPlugIn:identifier options:PKReloadOptionsDefault completion:nil];
                }
            }
        }];
    }];

    timers[identifier] = timer;
}

@end
