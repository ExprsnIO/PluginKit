# PlugInKit

A modern, extensible plugin framework for macOS with XPC-based communication, introspection, and scripting support.

## Features

- ✨ **Modern API Design**: Network.framework-inspired architecture with state management and completion handlers
- 🔌 **Bidirectional Communication**: Full XPC-based communication between host and plugins
- 🔮 **Futures/Promises**: Complete futures implementation with then, catch, while, and composition over XPC
- 🔍 **Method Introspection**: Discover and analyze plugin capabilities at runtime
- 📝 **Scripting Bridge**: Auto-generate AppleScript and JavaScript definitions
- 💓 **Connection Health Monitoring**: Automatic polling with latency tracking
- 🎯 **Selective Method Exposure**: Control which methods are exposed to scripting environments
- 🛡️ **Type-Safe**: Objective-C protocols with NSSecureCoding support
- 🚀 **Swift Compatible**: Full Swift interoperability with async/await and Combine

## Architecture

PlugInKit consists of several key components:

### Core Components

- **PKPlugInManager**: Central manager for plugin discovery and connection management
- **PKConnection**: Individual plugin connection with health monitoring and polling
- **PKXPCService**: Modern XPC service wrapper with state management

### Protocols

- **PKPlugInProtocol**: Required protocol for all plugins
- **PKHostProtocol**: Optional protocol for host applications to receive plugin notifications

### Introspection

- **PKIntrospector**: Analyzes plugin capabilities and exposed methods
- **PKMethodMetadata**: Describes plugin methods with exposure options

### Scripting Bridge

- **PKScriptingDefinitionGenerator**: Generates AppleScript, JavaScript, and SDEF definitions

### Futures

- **PKFuture**: Composable futures/promises for async XPC operations
- **Chaining**: then, map, flatMap, catch, finally
- **Composition**: all, any, race, sequence, zip
- **Iteration**: while, repeat, forEach
- **Swift Support**: async/await integration, Combine publishers, type-safe wrappers

## Quick Start

### 1. Create a Plugin

```objective-c
// MyPlugin.h
@interface MyPlugin : NSObject <PKPlugInProtocol>
@end

// MyPlugin.m
@implementation MyPlugin

- (void)initializeWithConfiguration:(NSDictionary *)configuration
                              reply:(void (^)(NSError *))reply {
    // Initialize your plugin
    reply(nil);
}

- (void)exposedMethodsWithReply:(void (^)(NSArray<PKMethodMetadata *> *))reply {
    PKMethodMetadata *method = [[PKMethodMetadata alloc]
        initWithSelector:@"processData:reply:"
        displayName:@"Process Data"
        description:@"Processes input data"
        exposureOptions:PKMethodExposureAll
        parameterTypes:@[@"@\"NSString\""]
        returnType:@"@\"NSString\""];

    reply(@[method]);
}

- (void)processData:(NSString *)data reply:(void (^)(NSString *))reply {
    NSString *result = [data uppercaseString];
    reply(result);
}

@end
```

### 2. Create XPC Service

```objective-c
// main.m
int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSXPCListener *listener = [NSXPCListener serviceListener];
        listener.delegate = [[PlugInServiceDelegate alloc] init];
        [listener resume];
        [[NSRunLoop currentRunLoop] run];
    }
    return 0;
}
```

### 3. Use in Host Application

```objective-c
PKPlugInManager *manager = [PKPlugInManager sharedManager];
manager.pollingEnabled = YES;

[manager discoverPlugInsWithCompletion:^(NSArray<PKPlugInInfo *> *plugIns, NSError *error) {
    for (PKPlugInInfo *info in plugIns) {
        [manager connectToPlugIn:info.identifier
                   configuration:@{}
                      completion:^(PKConnection *connection, NSError *error) {
            // Use connection
            id<PKPlugInProtocol> plugin = [connection remotePlugInWithErrorHandler:^(NSError *err) {
                NSLog(@"Error: %@", err);
            }];

            // Call plugin methods
            [plugin processData:@"hello" reply:^(NSString *result) {
                NSLog(@"Result: %@", result);
            }];
        }];
    }
}];
```

## Swift Support

PlugInKit is fully compatible with Swift:

```swift
import PlugInKit

class MySwiftPlugin: NSObject, PKPlugInProtocol {
    func initialize(withConfiguration configuration: [String : Any],
                   reply: @escaping (Error?) -> Void) {
        // Initialize
        reply(nil)
    }

    func exposedMethods(reply: @escaping ([PKMethodMetadata]) -> Void) {
        let method = PKMethodMetadata(
            selector: "processData:reply:",
            displayName: "Process Data",
            description: "Processes input data",
            exposureOptions: .all,
            parameterTypes: ["@\"NSString\""],
            returnType: "@\"NSString\""
        )
        reply([method])
    }
}
```

## Connection Health Monitoring

PlugInKit automatically monitors connection health with configurable polling:

```objective-c
connection.pollingEnabled = YES;
connection.pollingInterval = 5.0;
connection.degradedLatencyThreshold = 1.0;
connection.unhealthyLatencyThreshold = 3.0;

connection.delegate = self;

- (void)connection:(PKConnection *)connection
   didChangeHealth:(PKConnectionHealth)health {
    switch (health) {
        case PKConnectionHealthHealthy:
            NSLog(@"Connection is healthy");
            break;
        case PKConnectionHealthDegraded:
            NSLog(@"Connection is degraded");
            break;
        case PKConnectionHealthUnhealthy:
            NSLog(@"Connection is unhealthy");
            break;
    }
}
```

## Method Introspection

Analyze plugin capabilities at runtime:

```objective-c
[PKIntrospector introspectConnection:connection
                          completion:^(PKIntrospectionResult *result, NSError *error) {
    NSLog(@"Plugin: %@", result.plugInIdentifier);
    NSLog(@"Capabilities: %@", result.capabilities);

    for (PKMethodMetadata *method in result.methods) {
        NSLog(@"Method: %@ - %@", method.displayName, method.methodDescription);
        NSLog(@"Signature: %@", [PKIntrospector signatureForMethod:method]);
    }

    // Filter by exposure
    NSArray *appleScriptMethods = [result methodsWithExposureOptions:PKMethodExposureAppleScript];
}];
```

## Scripting Bridge

Generate scripting definitions for automation:

```objective-c
// AppleScript
NSString *applescript = [PKScriptingDefinitionGenerator
    generateDefinitionFromIntrospectionResult:result
    format:PKScriptingDefinitionFormatAppleScript
    options:PKScriptingDefinitionOptionsVerbose];

// JavaScript for Automation (JXA)
NSString *javascript = [PKScriptingDefinitionGenerator
    generateDefinitionFromIntrospectionResult:result
    format:PKScriptingDefinitionFormatJavaScript
    options:PKScriptingDefinitionOptionsIncludeTypes];

// SDEF (Scripting Definition XML)
NSString *sdef = [PKScriptingDefinitionGenerator
    generateSDEFFromIntrospectionResults:@[result]
    suiteName:@"MyApp"
    options:PKScriptingDefinitionOptionsNone];

// Export to file
[PKScriptingDefinitionGenerator exportDefinition:sdef
                                           toURL:url
                                           error:&error];
```

## Method Exposure Control

Control which methods are accessible from scripting environments:

```objective-c
typedef NS_OPTIONS(NSUInteger, PKMethodExposureOptions) {
    PKMethodExposureNone        = 0,
    PKMethodExposureAppleScript = 1 << 0,
    PKMethodExposureJavaScript  = 1 << 1,
    PKMethodExposureAll         = PKMethodExposureAppleScript | PKMethodExposureJavaScript
};

// Expose to AppleScript only
PKMethodMetadata *method = [[PKMethodMetadata alloc]
    initWithSelector:@"calculate:reply:"
    displayName:@"Calculate"
    description:@"Performs calculation"
    exposureOptions:PKMethodExposureAppleScript
    parameterTypes:@[@"d"]
    returnType:@"d"];

// Expose to JavaScript only
PKMethodMetadata *jsMethod = [[PKMethodMetadata alloc]
    initWithSelector:@"getStatus:reply:"
    displayName:@"Get Status"
    description:@"Returns status"
    exposureOptions:PKMethodExposureJavaScript
    parameterTypes:@[]
    returnType:@"@\"NSDictionary\""];

// Internal method (not exposed)
PKMethodMetadata *internal = [[PKMethodMetadata alloc]
    initWithSelector:@"internalMethod:reply:"
    displayName:@"Internal"
    description:@"Internal only"
    exposureOptions:PKMethodExposureNone
    parameterTypes:@[]
    returnType:@"v"];
```

## Bidirectional Communication

Plugins can send notifications back to the host:

```objective-c
// Host implements PKHostProtocol
@interface MyHostApp : NSObject <PKHostProtocol>
@end

@implementation MyHostApp

- (void)didReceiveNotification:(NSDictionary *)notification
                    fromPlugIn:(NSString *)plugInIdentifier
                         reply:(void (^)(BOOL acknowledged))reply {
    NSLog(@"Received notification from %@: %@", plugInIdentifier, notification);
    reply(YES);
}

- (void)requestPermissionForOperation:(NSString *)operation
                              context:(NSDictionary *)context
                           fromPlugIn:(NSString *)plugInIdentifier
                                reply:(void (^)(BOOL granted, NSError *error))reply {
    // Check permissions
    BOOL granted = [self checkPermission:operation];
    reply(granted, nil);
}

@end
```

## Plugin Bundle Configuration

Add to your plugin's `Info.plist`:

```xml
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.example.myplugin</string>

    <key>CFBundleName</key>
    <string>MyPlugin</string>

    <key>CFBundleShortVersionString</key>
    <string>1.0</string>

    <key>PKXPCServiceName</key>
    <string>com.example.myplugin.xpc</string>
</dict>
```

## Requirements

- macOS 10.15 or later
- Xcode 12 or later
- Objective-C 2.0 or Swift 5.0+

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/ExprsnIO/PluginKit.git", from: "1.0.0")
]
```

### Manual Integration

1. Clone the repository
2. Add `PlugInKit.xcodeproj` to your workspace
3. Link against `PlugInKit.framework`

## Examples

See the `Examples` directory for:

- **SamplePlugin**: Complete plugin implementation
- **HostApp**: Host application demonstrating all features

## License

MIT License - See LICENSE file for details

## Author

Rick Holland

Copyright (c) 2025
