//
//  PKPlugInManager+Lifecycle.m
//  PlugInKit
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

#import "PKPlugInManager+Lifecycle.h"
#import "PKConnection.h"
#import "PKError.h"
#import "PKLogger.h"
#import <objc/runtime.h>

#if __has_include(<AppKit/AppKit.h>)
#import <AppKit/AppKit.h>
#define PK_HAS_APPKIT 1
#endif

const NSTimeInterval PKLifecycleDefaultSuspendDrainTimeout = 5.0;

static const void *PKSuspendOnSystemSleepKey = &PKSuspendOnSystemSleepKey;

@implementation PKPlugInManager (Lifecycle)

// MARK: - System Sleep Integration

- (BOOL)suspendOnSystemSleep {
    NSNumber *value = objc_getAssociatedObject(self, PKSuspendOnSystemSleepKey);
    return value ? value.boolValue : NO;
}

- (void)setSuspendOnSystemSleep:(BOOL)suspendOnSystemSleep {
    BOOL current = self.suspendOnSystemSleep;
    if (current == suspendOnSystemSleep) {
        return;
    }
    objc_setAssociatedObject(self, PKSuspendOnSystemSleepKey, @(suspendOnSystemSleep),
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);

#if PK_HAS_APPKIT
    NSNotificationCenter *center = [[NSWorkspace sharedWorkspace] notificationCenter];
    if (suspendOnSystemSleep) {
        [center addObserver:self
                   selector:@selector(pk_systemWillSleep:)
                       name:NSWorkspaceWillSleepNotification
                     object:nil];
        [center addObserver:self
                   selector:@selector(pk_systemDidWake:)
                       name:NSWorkspaceDidWakeNotification
                     object:nil];
    } else {
        [center removeObserver:self name:NSWorkspaceWillSleepNotification object:nil];
        [center removeObserver:self name:NSWorkspaceDidWakeNotification object:nil];
    }
#endif
}

#if PK_HAS_APPKIT
- (void)pk_systemWillSleep:(NSNotification *)notification {
    for (PKConnection *connection in self.activeConnections) {
        if (!connection.isSuspended) {
            [self suspendPlugIn:connection.plugInIdentifier completion:nil];
        }
    }
}

- (void)pk_systemDidWake:(NSNotification *)notification {
    for (PKConnection *connection in self.activeConnections) {
        if (connection.isSuspended) {
            [self resumePlugIn:connection.plugInIdentifier completion:nil];
        }
    }
}
#endif

// MARK: - Suspend / Resume

- (void)suspendPlugIn:(NSString *)identifier
           completion:(nullable void (^)(NSError * _Nullable error))completion {
    [self suspendPlugIn:identifier
       withDrainTimeout:PKLifecycleDefaultSuspendDrainTimeout
             completion:completion];
}

- (void)suspendPlugIn:(NSString *)identifier
     withDrainTimeout:(NSTimeInterval)drainTimeout
           completion:(nullable void (^)(NSError * _Nullable error))completion {
    PKLogger *logger = [PKLogger loggerWithCategory:@"Lifecycle"];

    PKConnection *connection = [self connectionForPlugIn:identifier];
    if (!connection) {
        NSError *error = [NSError pk_errorWithCode:PKErrorPlugInNotFound
                                       description:@"No active connection for plugin"
                                          userInfo:@{PKErrorPlugInIdentifierKey: identifier}];
        if (completion) completion(error);
        return;
    }

    [logger info:@"[%@] Suspending plugin", identifier];

    [connection suspendWithDrainTimeout:drainTimeout completion:^(NSError * _Nullable error) {
        id<PKPlugInManagerLifecycleDelegate> delegate = self.lifecycleDelegate;
        if ([delegate respondsToSelector:@selector(plugInManager:willSuspendPlugIn:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [delegate plugInManager:self willSuspendPlugIn:identifier];
            });
        }
        if (completion) completion(error);
    }];
}

- (void)resumePlugIn:(NSString *)identifier
          completion:(nullable void (^)(NSError * _Nullable error))completion {
    PKLogger *logger = [PKLogger loggerWithCategory:@"Lifecycle"];

    PKConnection *connection = [self connectionForPlugIn:identifier];
    if (!connection) {
        NSError *error = [NSError pk_errorWithCode:PKErrorPlugInNotFound
                                       description:@"No active connection for plugin"
                                          userInfo:@{PKErrorPlugInIdentifierKey: identifier}];
        if (completion) completion(error);
        return;
    }

    [logger info:@"[%@] Resuming plugin", identifier];

    [connection resumeWithCompletion:^(NSError * _Nullable error) {
        id<PKPlugInManagerLifecycleDelegate> delegate = self.lifecycleDelegate;
        if ([delegate respondsToSelector:@selector(plugInManager:didResumePlugIn:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [delegate plugInManager:self didResumePlugIn:identifier];
            });
        }
        if (completion) completion(error);
    }];
}

@end
