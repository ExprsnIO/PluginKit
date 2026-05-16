//
//  main.m
//  HostApp
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <PlugInKit/PlugInKit.h>

@interface HostAppDelegate : NSObject <PKPlugInManagerDelegate,
                                       PKConnectionDelegate,
                                       PKPlugInManagerLifecycleDelegate,
                                       PKPlugInManagerResourceDelegate>

@property (nonatomic, strong) PKPlugInManager *plugInManager;

@end

@implementation HostAppDelegate

- (instancetype)init {
    if (self = [super init]) {
        _plugInManager = [PKPlugInManager sharedManager];
        _plugInManager.delegate = self;
        _plugInManager.lifecycleDelegate = self;
        _plugInManager.resourceDelegate = self;
        _plugInManager.pollingEnabled = YES;
        _plugInManager.defaultPollingInterval = 3.0;
    }
    return self;
}

- (void)run {
    NSLog(@"=== PlugInKit Host Application ===\n");

    // Discover plugins
    NSLog(@"Discovering plugins...");
    [self.plugInManager discoverPlugInsWithCompletion:^(NSArray<PKPlugInInfo *> *plugIns, NSError * _Nullable error) {
        if (error) {
            NSLog(@"Error discovering plugins: %@", error);
            return;
        }

        NSLog(@"Found %lu plugin(s):", (unsigned long)plugIns.count);
        for (PKPlugInInfo *info in plugIns) {
            NSLog(@"  - %@ (%@) v%@", info.name, info.identifier, info.version);
        }

        if (plugIns.count > 0) {
            [self connectToPlugin:plugIns.firstObject];
        } else {
            NSLog(@"\nNo plugins found. This is expected in example mode.");
            [self demonstrateAPIUsage];
        }
    }];
}

- (void)connectToPlugin:(PKPlugInInfo *)plugInInfo {
    NSLog(@"\nConnecting to plugin: %@", plugInInfo.identifier);

    NSDictionary *config = @{
        @"mode": @"production",
        @"debug": @YES
    };

    [self.plugInManager connectToPlugIn:plugInInfo.identifier
                          configuration:config
                             completion:^(PKConnection * _Nullable connection, NSError * _Nullable error) {
        if (error) {
            NSLog(@"Failed to connect: %@", error);
            return;
        }

        NSLog(@"Successfully connected to plugin!");
        connection.delegate = self;

        [self testPluginConnection:connection];
    }];
}

- (void)testPluginConnection:(PKConnection *)connection {
    NSLog(@"\n=== Testing Plugin Connection ===");

    // Test 1: Get capabilities
    id<PKPlugInProtocol> plugin = [connection remotePlugInWithErrorHandler:^(NSError *error) {
        NSLog(@"Error getting remote plugin: %@", error);
    }];

    if ([plugin respondsToSelector:@selector(capabilitiesWithReply:)]) {
        [plugin capabilitiesWithReply:^(NSDictionary<NSString *,id> * _Nonnull capabilities) {
            NSLog(@"\nPlugin Capabilities:");
            for (NSString *key in capabilities) {
                NSLog(@"  %@: %@", key, capabilities[key]);
            }

            // Test 2: Introspect methods
            [self introspectPlugin:connection];
        }];
    } else {
        [self introspectPlugin:connection];
    }
}

- (void)introspectPlugin:(PKConnection *)connection {
    NSLog(@"\n=== Introspecting Plugin ===");

    [PKIntrospector introspectConnection:connection completion:^(PKIntrospectionResult * _Nullable result, NSError * _Nullable error) {
        if (error) {
            NSLog(@"Introspection error: %@", error);
            return;
        }

        NSLog(@"Found %lu exposed methods:", (unsigned long)result.methods.count);

        for (PKMethodMetadata *method in result.methods) {
            NSLog(@"\n  Method: %@", method.displayName);
            NSLog(@"    Selector: %@", method.selector);
            NSLog(@"    Description: %@", method.methodDescription ?: @"N/A");
            NSLog(@"    Exposure: AppleScript=%d JavaScript=%d",
                  (method.exposureOptions & PKMethodExposureAppleScript) != 0,
                  (method.exposureOptions & PKMethodExposureJavaScript) != 0);
            NSLog(@"    Signature: %@", [PKIntrospector signatureForMethod:method]);
        }

        // Generate scripting definitions
        [self generateScriptingDefinitions:result];

        // Test sending messages
        [self testMessaging:connection];
    }];
}

- (void)generateScriptingDefinitions:(PKIntrospectionResult *)result {
    NSLog(@"\n=== Generating Scripting Definitions ===");

    // AppleScript
    NSString *applescript = [PKScriptingDefinitionGenerator
        generateDefinitionFromIntrospectionResult:result
        format:PKScriptingDefinitionFormatAppleScript
        options:PKScriptingDefinitionOptionsVerbose];

    NSLog(@"\nAppleScript Definition:\n%@", applescript);

    // JavaScript
    NSString *javascript = [PKScriptingDefinitionGenerator
        generateDefinitionFromIntrospectionResult:result
        format:PKScriptingDefinitionFormatJavaScript
        options:PKScriptingDefinitionOptionsIncludeTypes];

    NSLog(@"\nJavaScript Definition:\n%@", javascript);

    // SDEF
    NSString *sdef = [PKScriptingDefinitionGenerator
        generateSDEFFromIntrospectionResults:@[result]
        suiteName:@"SamplePlugin"
        options:PKScriptingDefinitionOptionsNone];

    NSLog(@"\nSDEF Definition:\n%@", sdef);
}

- (void)testMessaging:(PKConnection *)connection {
    NSLog(@"\n=== Testing Bidirectional Communication ===");

    id<PKPlugInProtocol> plugin = [connection remotePlugInWithErrorHandler:^(NSError *error) {
        NSLog(@"Error: %@", error);
    }];

    if ([plugin respondsToSelector:@selector(handleMessage:reply:)]) {
        NSDictionary *message = @{
            @"action": @"echo",
            @"data": @"Hello from host!"
        };

        [plugin handleMessage:message reply:^(NSDictionary<NSString *,id> * _Nullable response, NSError * _Nullable error) {
            if (error) {
                NSLog(@"Message error: %@", error);
            } else {
                NSLog(@"Message response: %@", response);
            }

            // Test connection polling
            [self testPolling:connection];
        }];
    } else {
        [self testPolling:connection];
    }
}

- (void)testPolling:(PKConnection *)connection {
    NSLog(@"\n=== Testing Connection Polling ===");
    NSLog(@"Polling enabled: %d", connection.isPollingEnabled);
    NSLog(@"Polling interval: %.2f seconds", connection.pollingInterval);

    [connection pollWithCompletion:^(BOOL success, NSTimeInterval latency, NSError * _Nullable error) {
        if (success) {
            NSLog(@"Poll successful! Latency: %.3f seconds", latency);
            NSLog(@"Connection health: %ld", (long)connection.health);
            NSLog(@"Average latency: %.3f seconds", connection.averageLatency);
        } else {
            NSLog(@"Poll failed: %@", error);
        }

        [self testLifecycleControl:connection];
    }];
}

- (void)testLifecycleControl:(PKConnection *)connection {
    NSLog(@"\n=== Testing Lifecycle Suspend / Resume ===");

    // Apply a resource limit so the monitor watches this plugin.
    [self.plugInManager setMemoryLimit:(256 * 1024 * 1024) forPlugIn:connection.plugInIdentifier];
    NSLog(@"Set 256 MB memory limit on %@", connection.plugInIdentifier);

    [self.plugInManager suspendPlugIn:connection.plugInIdentifier completion:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"Suspend reported: %@", error.localizedDescription);
        }
        NSLog(@"Plugin suspended (state=%ld)", (long)connection.state);

        [self.plugInManager resumePlugIn:connection.plugInIdentifier completion:^(NSError * _Nullable resumeError) {
            if (resumeError) {
                NSLog(@"Resume failed: %@", resumeError);
            } else {
                NSLog(@"Plugin resumed (state=%ld)", (long)connection.state);
            }
            NSLog(@"\n=== Test Complete ===");
        }];
    }];
}

- (void)demonstrateAPIUsage {
    NSLog(@"\n=== PlugInKit API Usage Examples ===\n");

    NSLog(@"1. Plugin Discovery:");
    NSLog(@"   [plugInManager discoverPlugInsWithCompletion:^(NSArray<PKPlugInInfo *> *plugIns, NSError *error) {");
    NSLog(@"       // Handle discovered plugins");
    NSLog(@"   }];");

    NSLog(@"\n2. Connect to Plugin:");
    NSLog(@"   [plugInManager connectToPlugIn:identifier");
    NSLog(@"                    configuration:config");
    NSLog(@"                       completion:^(PKConnection *connection, NSError *error) {");
    NSLog(@"       // Use connection");
    NSLog(@"   }];");

    NSLog(@"\n3. Introspect Plugin:");
    NSLog(@"   [PKIntrospector introspectConnection:connection");
    NSLog(@"                             completion:^(PKIntrospectionResult *result, NSError *error) {");
    NSLog(@"       // Analyze methods and capabilities");
    NSLog(@"   }];");

    NSLog(@"\n4. Generate Scripting Definitions:");
    NSLog(@"   NSString *def = [PKScriptingDefinitionGenerator");
    NSLog(@"       generateDefinitionFromIntrospectionResult:result");
    NSLog(@"                                          format:PKScriptingDefinitionFormatAppleScript");
    NSLog(@"                                         options:PKScriptingDefinitionOptionsVerbose];");

    NSLog(@"\n5. Connection Polling:");
    NSLog(@"   connection.pollingEnabled = YES;");
    NSLog(@"   connection.pollingInterval = 5.0;");
    NSLog(@"   // Automatic health monitoring");

    NSLog(@"\n6. Bidirectional Communication:");
    NSLog(@"   [plugin handleMessage:message reply:^(NSDictionary *response, NSError *error) {");
    NSLog(@"       // Handle response");
    NSLog(@"   }];");
}

#pragma mark - PKPlugInManagerDelegate

- (void)plugInManager:(PKPlugInManager *)manager didDiscoverPlugIn:(PKPlugInInfo *)plugInInfo {
    NSLog(@"[Delegate] Discovered plugin: %@", plugInInfo.name);
}

- (void)plugInManager:(PKPlugInManager *)manager didEstablishConnection:(PKConnection *)connection {
    NSLog(@"[Delegate] Established connection to: %@", connection.plugInIdentifier);
}

- (void)plugInManager:(PKPlugInManager *)manager
didFailToConnectToPlugIn:(NSString *)identifier
                error:(NSError *)error {
    NSLog(@"[Delegate] Failed to connect to %@: %@", identifier, error);
}

#pragma mark - PKConnectionDelegate

- (void)connection:(PKConnection *)connection didChangeHealth:(PKConnectionHealth)health {
    NSString *healthStr = @"Unknown";
    switch (health) {
        case PKConnectionHealthHealthy: healthStr = @"Healthy"; break;
        case PKConnectionHealthDegraded: healthStr = @"Degraded"; break;
        case PKConnectionHealthUnhealthy: healthStr = @"Unhealthy"; break;
        default: break;
    }
    NSLog(@"[Delegate] Connection %@ health changed to: %@", connection.plugInIdentifier, healthStr);
}

- (void)connection:(PKConnection *)connection didChangeState:(PKXPCConnectionState)state {
    NSLog(@"[Delegate] Connection %@ state changed to: %ld", connection.plugInIdentifier, (long)state);
}

- (void)connection:(PKConnection *)connection didCompletePoll:(BOOL)success latency:(NSTimeInterval)latency {
    NSLog(@"[Delegate] Poll %@ - latency: %.3fs", success ? @"succeeded" : @"failed", latency);
}

#pragma mark - PKPlugInManagerLifecycleDelegate

- (void)plugInManager:(PKPlugInManager *)manager willLoadPlugIn:(NSString *)identifier {
    NSLog(@"[Lifecycle] willLoad: %@", identifier);
}

- (void)plugInManager:(PKPlugInManager *)manager didLoadPlugIn:(NSString *)identifier {
    NSLog(@"[Lifecycle] didLoad: %@", identifier);
}

- (void)plugInManager:(PKPlugInManager *)manager willUnloadPlugIn:(NSString *)identifier {
    NSLog(@"[Lifecycle] willUnload: %@", identifier);
}

- (void)plugInManager:(PKPlugInManager *)manager didUnloadPlugIn:(NSString *)identifier {
    NSLog(@"[Lifecycle] didUnload: %@", identifier);
}

- (void)plugInManager:(PKPlugInManager *)manager willSuspendPlugIn:(NSString *)identifier {
    NSLog(@"[Lifecycle] suspended: %@", identifier);
}

- (void)plugInManager:(PKPlugInManager *)manager didResumePlugIn:(NSString *)identifier {
    NSLog(@"[Lifecycle] resumed: %@", identifier);
}

#pragma mark - PKPlugInManagerResourceDelegate

- (void)plugInManager:(PKPlugInManager *)manager
       plugIn:(NSString *)identifier
 didExceedMemoryLimit:(size_t)limitBytes
              current:(size_t)currentBytes {
    NSLog(@"[Resource] %@ exceeded memory limit: %zu > %zu", identifier, currentBytes, limitBytes);
}

- (void)plugInManager:(PKPlugInManager *)manager
       plugIn:(NSString *)identifier
    didExceedCPULimit:(double)limitPercentage
              current:(double)currentPercentage {
    NSLog(@"[Resource] %@ exceeded CPU limit: %.1f%% > %.1f%%", identifier, currentPercentage, limitPercentage);
}

- (void)plugInManager:(PKPlugInManager *)manager
didDisconnectPlugInForResourceViolation:(NSString *)identifier
                error:(NSError *)error {
    NSLog(@"[Resource] %@ disconnected for resource violation: %@", identifier, error.localizedDescription);
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        HostAppDelegate *delegate = [[HostAppDelegate alloc] init];
        [delegate run];

        [[NSRunLoop currentRunLoop] run];
    }
    return 0;
}
