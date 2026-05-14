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
#import "../../PlugInKitProtocol/PKPlugInProtocol.h"
#import "../../PlugInKitProtocol/PKPlugInState.h"
#import <objc/runtime.h>

NSNotificationName const PKPlugInDidReloadNotification = @"PKPlugInDidReloadNotification";
NSString *const PKPlugInReloadIdentifierKey = @"PKPlugInReloadIdentifier";
NSString *const PKPlugInReloadOldVersionKey = @"PKPlugInReloadOldVersion";
NSString *const PKPlugInReloadNewVersionKey = @"PKPlugInReloadNewVersion";

// Associated object keys
static const void *PKHotReloadEnabledKey = &PKHotReloadEnabledKey;
static const void *PKAutomaticReloadEnabledKey = &PKAutomaticReloadEnabledKey;
static const void *PKReloadCheckIntervalKey = &PKReloadCheckIntervalKey;
static const void *PKReloadStatesKey = &PKReloadStatesKey;
static const void *PKReloadTimersKey = &PKReloadTimersKey;

/// Envelope-based state migration handler used internally by the reload worker.
typedef PKPlugInState * _Nullable (^PKEnvelopeMigrationHandler)(PKPlugInState * _Nullable oldState);

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

// MARK: - Public Reload Methods

- (void)reloadPlugIn:(NSString *)identifier
             options:(PKReloadOptions)options
          completion:(void (^)(BOOL success, NSError *error))completion {
    PKEnvelopeMigrationHandler handler = nil;
    if (options & PKReloadOptionsPreserveState) {
        handler = ^PKPlugInState *(PKPlugInState *oldState) {
            return oldState;  // preserve as-is
        };
    }
    [self pk_reloadPlugIn:identifier
                  options:options
        envelopeMigration:handler
               completion:completion];
}

- (void)reloadPlugIn:(NSString *)identifier
withStateMigration:(NSDictionary * (^)(NSDictionary *oldState))stateMigrationHandler
          completion:(void (^)(BOOL success, NSError *error))completion {
    PKEnvelopeMigrationHandler handler = nil;
    if (stateMigrationHandler) {
        handler = ^PKPlugInState *(PKPlugInState *oldState) {
            NSDictionary *migratedPayload = stateMigrationHandler(oldState.payload);
            if (!migratedPayload) {
                return nil;
            }
            return [[PKPlugInState alloc] initWithIdentifier:oldState.identifier ?: identifier
                                                     version:oldState.version ?: @""
                                                     payload:migratedPayload];
        };
    }
    [self pk_reloadPlugIn:identifier
                  options:PKReloadOptionsDefault
        envelopeMigration:handler
               completion:completion];
}

- (void)reloadPlugIn:(NSString *)identifier
withStateEnvelopeMigration:(PKPlugInState * _Nullable (^)(PKPlugInState * _Nullable))stateMigrationHandler
          completion:(void (^)(BOOL success, NSError *error))completion {
    [self pk_reloadPlugIn:identifier
                  options:PKReloadOptionsDefault
        envelopeMigration:stateMigrationHandler
               completion:completion];
}

// MARK: - Reload Worker

- (void)pk_reloadPlugIn:(NSString *)identifier
                options:(PKReloadOptions)options
      envelopeMigration:(nullable PKEnvelopeMigrationHandler)envelopeMigration
             completion:(void (^)(BOOL success, NSError *error))completion {

    PKLogger *logger = [PKLogger loggerWithCategory:@"HotReload"];
    [logger info:@"[%@] Starting hot-reload", identifier];

    if (!self.isHotReloadEnabled) {
        NSError *error = [NSError pk_errorWithCode:PKErrorInvalidState
                                       description:@"Hot-reload is not enabled"];
        if (completion) completion(NO, error);
        return;
    }

    PKReloadState currentState = [self reloadStateForPlugIn:identifier];
    if (currentState != PKReloadStateIdle &&
        currentState != PKReloadStateCompleted &&
        currentState != PKReloadStateFailed &&
        currentState != PKReloadStateRolledBack) {
        NSError *error = [NSError pk_errorWithCode:PKErrorReloadInProgress
                                       description:@"Reload is already in progress"];
        if (completion) completion(NO, error);
        return;
    }

    PKPlugInInfo *currentPlugIn = [self plugInInfoForIdentifier:identifier];
    if (!currentPlugIn) {
        NSError *error = [NSError pk_errorWithCode:PKErrorPlugInNotFound
                                       description:@"Plugin not found"];
        if (completion) completion(NO, error);
        return;
    }

    [self setReloadState:PKReloadStatePreparing forPlugIn:identifier];

    PKConnection *existingConnection = [self connectionForPlugIn:identifier];
    NSString *oldVersion = currentPlugIn.version;
    NSURL *oldBundleURL = currentPlugIn.bundleURL;

    // Step 1: Extract and migrate state.
    [self setReloadState:PKReloadStateMigratingState forPlugIn:identifier];

    void (^continueWithEnvelope)(PKPlugInState * _Nullable) = ^(PKPlugInState * _Nullable migratedEnvelope) {
        [self pk_continueReloadForPlugIn:identifier
                          savedEnvelope:migratedEnvelope
                             oldVersion:oldVersion
                           oldBundleURL:oldBundleURL
                                options:options
                             completion:completion];
    };

    if (existingConnection && envelopeMigration) {
        id<PKPlugInProtocol> plugin = [existingConnection remotePlugInWithErrorHandler:^(NSError *error) {
            [logger error:@"[%@] Failed to connect for state extraction: %@", identifier, error];
            continueWithEnvelope(nil);
        }];

        if ([plugin respondsToSelector:@selector(capabilitiesWithReply:)]) {
            [plugin capabilitiesWithReply:^(NSDictionary *capabilities) {
                NSDictionary *rawState = capabilities[@"state"];
                PKPlugInState *envelope =
                    [[PKPlugInState alloc] initWithIdentifier:identifier
                                                     version:oldVersion
                                                     payload:[rawState isKindOfClass:[NSDictionary class]] ? rawState : @{}];
                PKPlugInState *migrated = envelopeMigration(envelope);
                continueWithEnvelope(migrated);
            }];
            return;
        }
    }

    continueWithEnvelope(nil);
}

- (void)pk_continueReloadForPlugIn:(NSString *)identifier
                     savedEnvelope:(nullable PKPlugInState *)savedEnvelope
                        oldVersion:(NSString *)oldVersion
                      oldBundleURL:(NSURL *)oldBundleURL
                           options:(PKReloadOptions)options
                        completion:(void (^)(BOOL success, NSError *error))completion {

    PKLogger *logger = [PKLogger loggerWithCategory:@"HotReload"];

    // Notify delegate that the reload is about to begin.
    id delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(plugInManager:willReloadPlugIn:)]) {
        PKPlugInInfo *plugIn = [self plugInInfoForIdentifier:identifier];
        [(id<PKPlugInManagerHotReloadDelegate>)delegate plugInManager:self willReloadPlugIn:plugIn];
    }

    // Step 2: Disconnect the existing instance.
    [self setReloadState:PKReloadStateReloading forPlugIn:identifier];
    [logger debug:@"[%@] Disconnecting old instance", identifier];
    [self disconnectFromPlugIn:identifier];

    // Step 3: Re-discover (picks up the new version on disk).
    [logger debug:@"[%@] Re-discovering plugin at: %@", identifier, oldBundleURL];

    [self discoverPlugInsAtURL:oldBundleURL.URLByDeletingLastPathComponent
                    completion:^(NSArray<PKPlugInInfo *> *plugIns, NSError *error) {

        if (error) {
            [logger error:@"[%@] Re-discovery failed: %@", identifier, error];
            NSError *reloadError = [NSError pk_errorWithCode:PKErrorReloadFailed
                                                 description:@"Failed to re-discover plugin"
                                             underlyingError:error];
            [self pk_handleReloadFailure:identifier
                           originalError:reloadError
                           savedEnvelope:savedEnvelope
                              oldVersion:oldVersion
                            oldBundleURL:oldBundleURL
                                 options:options
                              completion:completion];
            return;
        }

        PKPlugInInfo *newPlugIn = nil;
        for (PKPlugInInfo *p in plugIns) {
            if ([p.identifier isEqualToString:identifier]) {
                newPlugIn = p;
                break;
            }
        }

        if (!newPlugIn) {
            NSError *notFoundError = [NSError pk_errorWithCode:PKErrorPlugInNotFound
                                                  description:@"Plugin not found after re-discovery"];
            [self pk_handleReloadFailure:identifier
                           originalError:notFoundError
                           savedEnvelope:savedEnvelope
                              oldVersion:oldVersion
                            oldBundleURL:oldBundleURL
                                 options:options
                              completion:completion];
            return;
        }

        [logger info:@"[%@] Reloading from v%@ to v%@", identifier, oldVersion, newPlugIn.version];

        // Step 4: Compatibility check.
        NSError *compatError = nil;
        if (![self isPlugInCompatible:newPlugIn error:&compatError]) {
            [logger error:@"[%@] New version is incompatible: %@", identifier, compatError];
            [self pk_handleReloadFailure:identifier
                           originalError:compatError
                           savedEnvelope:savedEnvelope
                              oldVersion:oldVersion
                            oldBundleURL:oldBundleURL
                                 options:options
                              completion:completion];
            return;
        }

        // Step 5: Reconnect, restoring state from the envelope payload.
        NSMutableDictionary *config = [NSMutableDictionary dictionary];
        if (savedEnvelope.payload.count > 0) {
            config[@"restoredState"] = savedEnvelope.payload;
        }

        [self connectToPlugIn:identifier
                configuration:config
                   completion:^(PKConnection *connection, NSError *connectError) {

            if (connectError) {
                [logger error:@"[%@] Reconnection failed: %@", identifier, connectError];
                NSError *reloadError = [NSError pk_errorWithCode:PKErrorReloadFailed
                                                     description:@"Failed to reconnect to reloaded plugin"
                                                 underlyingError:connectError];
                [self pk_handleReloadFailure:identifier
                               originalError:reloadError
                               savedEnvelope:savedEnvelope
                                  oldVersion:oldVersion
                                oldBundleURL:oldBundleURL
                                     options:options
                                  completion:completion];
                return;
            }

            // Success.
            [self setReloadState:PKReloadStateCompleted forPlugIn:identifier];
            [logger info:@"[%@] Hot-reload completed successfully", identifier];

            id reloadDelegate = self.delegate;
            if ([reloadDelegate respondsToSelector:@selector(plugInManager:didReloadPlugIn:fromVersion:toVersion:)]) {
                [(id<PKPlugInManagerHotReloadDelegate>)reloadDelegate plugInManager:self
                                                                    didReloadPlugIn:newPlugIn
                                                                        fromVersion:oldVersion
                                                                          toVersion:newPlugIn.version];
            }

            // Notify clients via NSNotification when requested.
            if (options & PKReloadOptionsNotifyClients) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:PKPlugInDidReloadNotification
                                                                       object:self
                                                                     userInfo:@{
                                                                         PKPlugInReloadIdentifierKey: identifier,
                                                                         PKPlugInReloadOldVersionKey: oldVersion,
                                                                         PKPlugInReloadNewVersionKey: newPlugIn.version,
                                                                     }];
                });
            }

            if (completion) completion(YES, nil);
        }];
    }];
}

// MARK: - Rollback

- (void)pk_handleReloadFailure:(NSString *)identifier
                 originalError:(NSError *)originalError
                 savedEnvelope:(nullable PKPlugInState *)savedEnvelope
                    oldVersion:(NSString *)oldVersion
                  oldBundleURL:(NSURL *)oldBundleURL
                       options:(PKReloadOptions)options
                    completion:(void (^)(BOOL success, NSError *error))completion {

    PKLogger *logger = [PKLogger loggerWithCategory:@"HotReload"];

    if (!(options & PKReloadOptionsRollbackOnFailure)) {
        [self setReloadState:PKReloadStateFailed forPlugIn:identifier];
        [self pk_notifyReloadFailure:identifier error:originalError];
        if (completion) completion(NO, originalError);
        return;
    }

    // Best-effort rollback: reconnect to the original bundle location with the
    // previously captured state. If the bundle is no longer present, fail loudly.
    if (![[NSFileManager defaultManager] fileExistsAtPath:oldBundleURL.path]) {
        [logger error:@"[%@] Rollback impossible: original bundle no longer exists at %@",
         identifier, oldBundleURL.path];
        [self setReloadState:PKReloadStateFailed forPlugIn:identifier];
        NSError *rollbackError = [NSError pk_errorWithCode:PKErrorRollbackFailed
                                               description:@"Reload failed and the original bundle is no longer available for rollback"
                                                  userInfo:@{
                                                      PKErrorPlugInIdentifierKey: identifier,
                                                      PKErrorRollbackFailedKey: @YES,
                                                      NSUnderlyingErrorKey: originalError,
                                                  }];
        [self pk_notifyReloadFailure:identifier error:rollbackError];
        if (completion) completion(NO, rollbackError);
        return;
    }

    [logger warning:@"[%@] Reload failed; attempting rollback to original bundle", identifier];

    [self discoverPlugInsAtURL:oldBundleURL.URLByDeletingLastPathComponent
                    completion:^(NSArray<PKPlugInInfo *> *plugIns, NSError *discoverError) {

        BOOL rediscovered = NO;
        for (PKPlugInInfo *p in plugIns) {
            if ([p.identifier isEqualToString:identifier]) {
                rediscovered = YES;
                break;
            }
        }

        if (discoverError || !rediscovered) {
            [self setReloadState:PKReloadStateFailed forPlugIn:identifier];
            NSError *rollbackError = [NSError pk_errorWithCode:PKErrorRollbackFailed
                                                   description:@"Reload failed and rollback could not re-discover the original bundle"
                                                      userInfo:@{
                                                          PKErrorPlugInIdentifierKey: identifier,
                                                          PKErrorRollbackFailedKey: @YES,
                                                          NSUnderlyingErrorKey: originalError,
                                                      }];
            [self pk_notifyReloadFailure:identifier error:rollbackError];
            if (completion) completion(NO, rollbackError);
            return;
        }

        NSMutableDictionary *config = [NSMutableDictionary dictionary];
        if (savedEnvelope.payload.count > 0) {
            config[@"restoredState"] = savedEnvelope.payload;
        }

        [self connectToPlugIn:identifier
                configuration:config
                   completion:^(PKConnection *connection, NSError *connectError) {
            if (connectError) {
                [self setReloadState:PKReloadStateFailed forPlugIn:identifier];
                NSError *rollbackError = [NSError pk_errorWithCode:PKErrorRollbackFailed
                                                       description:@"Reload failed and rollback could not reconnect to the original bundle"
                                                          userInfo:@{
                                                              PKErrorPlugInIdentifierKey: identifier,
                                                              PKErrorRollbackFailedKey: @YES,
                                                              NSUnderlyingErrorKey: originalError,
                                                          }];
                [self pk_notifyReloadFailure:identifier error:rollbackError];
                if (completion) completion(NO, rollbackError);
                return;
            }

            [self setReloadState:PKReloadStateRolledBack forPlugIn:identifier];
            [logger info:@"[%@] Rolled back to original bundle after failed reload", identifier];

            // The reload itself did not succeed; report the original error so
            // callers know it failed, while reloadStateForPlugIn: reports the
            // recovered state.
            [self pk_notifyReloadFailure:identifier error:originalError];
            if (completion) completion(NO, originalError);
        }];
    }];
}

- (void)pk_notifyReloadFailure:(NSString *)identifier error:(NSError *)error {
    PKPlugInInfo *plugIn = [self plugInInfoForIdentifier:identifier];
    id delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(plugInManager:didFailToReloadPlugIn:error:)]) {
        [(id<PKPlugInManagerHotReloadDelegate>)delegate plugInManager:self
                                                didFailToReloadPlugIn:plugIn
                                                                error:error];
    }
}

// MARK: - Update Checking

- (void)checkForUpdates:(NSString *)identifier
             completion:(void (^)(BOOL hasUpdate, NSString *newVersion))completion {

    PKPlugInInfo *currentPlugIn = [self plugInInfoForIdentifier:identifier];
    if (!currentPlugIn) {
        if (completion) completion(NO, nil);
        return;
    }

    NSString *currentVersion = currentPlugIn.version;
    NSURL *bundleURL = currentPlugIn.bundleURL;

    NSBundle *bundle = [NSBundle bundleWithURL:bundleURL];
    [bundle load];

    NSString *newVersion = [bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];

    if (newVersion && ![newVersion isEqualToString:currentVersion]) {
        if (completion) completion(YES, newVersion);

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
    @synchronized ([self reloadStates]) {
        [self reloadStates][identifier] = @(state);
    }
}

- (void)cancelReload:(NSString *)identifier {
    PKReloadState state = [self reloadStateForPlugIn:identifier];
    if (state == PKReloadStateIdle ||
        state == PKReloadStateCompleted ||
        state == PKReloadStateFailed ||
        state == PKReloadStateRolledBack) {
        return;  // Nothing to cancel
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

    if (timers[identifier]) {
        return;
    }

    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:self.reloadCheckInterval
                                                      repeats:YES
                                                        block:^(NSTimer *t) {
        [self checkForUpdates:identifier completion:^(BOOL hasUpdate, NSString *newVersion) {
            if (hasUpdate) {
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
                    [self reloadPlugIn:identifier options:PKReloadOptionsDefault completion:nil];
                }
            }
        }];
    }];

    timers[identifier] = timer;
}

@end
