# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PlugInKit is a modern macOS plugin framework with XPC-based communication, inspired by Network.framework's API design. It enables host applications to discover, load, and communicate with plugins through secure XPC services, with support for futures/promises, introspection, and scripting bridge generation.

## Build Commands

```bash
# Build with Swift Package Manager
swift build

# Build for release
swift build -c release

# Open in Xcode
open PlugInKit.xcodeproj  # If Xcode project exists

# Clean build
swift package clean
```

Note: This project currently uses Swift Package Manager. There is no Xcode project file in the repository yet.

## Testing

While no test framework is currently set up, when adding tests:
- Use XCTest framework
- Mock XPC connections for unit tests
- Create integration tests for plugin discovery and communication
- Test bidirectional host-plugin communication
- Verify connection health monitoring and polling behavior

## Architecture

### Core Component Hierarchy

**PlugInKit is split into two main targets:**

1. **PlugInKitProtocol** (Sources/PlugInKitProtocol/)
   - Shared between host apps and plugins
   - Contains only protocol definitions: `PKPlugInProtocol`, `PKHostProtocol`
   - Minimal dependencies to reduce plugin bundle size
   - Both host and plugins link against this

2. **PlugInKit** (Sources/PlugInKit/)
   - Full framework for host applications only
   - Contains manager, connection handling, introspection, scripting
   - Depends on PlugInKitProtocol

### Core Subsystems

**Core/** - Plugin lifecycle and connection management
- `PKPlugInManager`: Singleton for plugin discovery and connection coordination
  - Discovers plugins from bundle directories (reads Info.plist for PKXPCServiceName)
  - Creates and manages `PKConnection` instances
  - Broadcasts messages to all connected plugins
  - Delegates notify about discovery/connection events

- `PKConnection`: Individual plugin connection wrapper
  - Wraps `PKXPCService` with plugin-specific behavior
  - Automatic health monitoring via polling (configurable interval)
  - Tracks latency and health states (healthy/degraded/unhealthy)
  - Provides both async and sync remote object proxies

**XPC/** - XPC service abstraction
- `PKXPCService`: Modern XPC wrapper with state management
  - States: ready → connecting → connected → disconnected/failed
  - Handles connection lifecycle (start/stop/invalidation)
  - Not plugin-specific; can be used for any XPC service

**Introspection/** - Runtime plugin analysis
- `PKIntrospector`: Queries plugins for exposed methods
  - Calls `exposedMethodsWithReply:` on plugin to get `PKMethodMetadata` array
  - Returns `PKIntrospectionResult` with capabilities and method signatures
  - Filters methods by exposure options (AppleScript/JavaScript/None)

**ScriptingBridge/** - Automation definition generation
- `PKScriptingDefinitionGenerator`: Generates scripting definitions
  - Converts introspection results to AppleScript/JXA/SDEF formats
  - Respects `PKMethodExposureOptions` to selectively expose methods
  - Generates type-safe scripting interfaces

**Futures/** - Composable async operations
- `PKFuture`: Promise/Future implementation for XPC operations
  - NSSecureCoding-compliant for XPC transfer
  - Chaining: then, map, flatMap, catch, finally
  - Composition: all, any, race, sequence, zip
  - Iteration: while, repeat, forEach
  - Timing: timeout, delay, after
  - See FUTURES.md for comprehensive guide

**Swift/** - Swift interoperability
- Type-safe `Future<T>` wrapper
- async/await integration
- Combine publisher support
- Result builders for pipeline construction

### Plugin Communication Flow

```
Host App
  ↓ (discovers plugins via PKPlugInManager)
  ↓ (reads Info.plist → PKXPCServiceName)
  ↓
PKConnection (wraps PKXPCService)
  ↓ (XPC connection)
  ↓
Plugin XPC Service
  ↓ (implements PKPlugInProtocol)
  ↓
Plugin Implementation

Bidirectional:
Plugin → Host (via PKHostProtocol)
  - didReceiveNotification:fromPlugIn:reply:
  - requestPermissionForOperation:context:fromPlugIn:reply:
```

### State Management Pattern

Following Network.framework conventions:
- Explicit state enums (e.g., `PKXPCConnectionState`)
- State transitions communicated via delegates
- Completion handlers for async operations
- Queue-based architecture for thread safety (all state modifications on serial queues)

## Key Patterns and Conventions

### XPC and Threading

- **All XPC communication is asynchronous by default**
- State management uses serial dispatch queues (never modify state from callbacks directly)
- `remotePlugInWithErrorHandler:` returns async proxy (preferred)
- `synchronousRemotePlugInWithErrorHandler:` returns sync proxy (use sparingly, never on main thread)
- XPC interruption/invalidation handlers should clean up state and notify delegates

### Protocol Design

Plugins must implement `PKPlugInProtocol`:
- `initializeWithConfiguration:reply:` - Called once when connection established
- `exposedMethodsWithReply:` - Returns array of `PKMethodMetadata` for introspection
- Custom methods should follow pattern: `methodName:param2:reply:` with completion block

Hosts can optionally implement `PKHostProtocol`:
- `didReceiveNotification:fromPlugIn:reply:` - Receive plugin notifications
- `requestPermissionForOperation:context:fromPlugIn:reply:` - Permission checks

### Connection Health Monitoring

- Enable with `connection.pollingEnabled = YES`
- Polls plugin with `pollWithCompletion:` at regular intervals
- Latency thresholds determine health state:
  - Healthy: latency < degradedLatencyThreshold (default 1.0s)
  - Degraded: latency < unhealthyLatencyThreshold (default 3.0s)
  - Unhealthy: latency >= unhealthyLatencyThreshold
- Delegate receives `connection:didChangeHealth:` callbacks

### Futures Best Practices

- Always handle errors with `catch` or `onFailure`
- Never use `wait` on main thread (blocks UI)
- Prefer chaining (`then`/`thenFuture`) over nested callbacks
- Add timeouts to prevent hanging: `[future timeout:10.0]`
- Use `finally` for cleanup (executes regardless of success/failure)
- For XPC operations, use `PKConnection+Futures` category methods

### Method Exposure Control

Methods are selectively exposed via `PKMethodExposureOptions`:
```objective-c
PKMethodExposureNone        = 0          // Internal only
PKMethodExposureAppleScript = 1 << 0     // Expose to AppleScript
PKMethodExposureJavaScript  = 1 << 1     // Expose to JXA
PKMethodExposureAll         = AppleScript | JavaScript
```

Use this to separate internal APIs from scripting interfaces.

## Code Organization

```
Sources/
├── PlugInKitProtocol/          # Minimal shared protocol library
│   ├── PKPlugInProtocol.h/m    # Required plugin protocol
│   ├── PKHostProtocol.h        # Optional host protocol
│   └── PKPlugInProtocol+Futures.h  # Futures extensions
│
└── PlugInKit/                  # Full framework (host-side only)
    ├── PlugInKit.h             # Umbrella header
    ├── Core/                   # Connection and manager
    ├── XPC/                    # XPC service wrapper
    ├── Introspection/          # Runtime analysis
    ├── ScriptingBridge/        # Definition generators
    ├── Futures/                # Async operations
    └── Swift/                  # Swift interoperability

Examples/
├── SamplePlugin/               # Objective-C plugin example
├── SwiftPlugin/                # Swift plugin example
├── HostApp/                    # Objective-C host example
├── SwiftHostApp/               # Swift host example
├── FuturesExample/             # Objective-C futures examples
└── SwiftFuturesExample/        # Swift futures examples
```

## Plugin Bundle Structure

Plugins must be macOS bundles (.bundle or .plugin) with:
- `Info.plist` containing:
  - `CFBundleIdentifier`: Unique plugin ID
  - `CFBundleName`: Display name
  - `CFBundleShortVersionString`: Version
  - `PKXPCServiceName`: XPC service name (e.g., "com.example.plugin.xpc")
- XPC service implementing `PKPlugInProtocol`
- Embedded XPC service in bundle's `Contents/XPCServices/` or system location

## Swift Interoperability

The framework is fully Swift-compatible:
- Use `@objc` and `@objcMembers` for plugin classes
- Import `PlugInKit` in Swift files
- Type-safe `Future<T>` wrapper available for compile-time type checking
- async/await integration with `future.async()` (macOS 12.0+)
- Combine integration with `future.publisher`

## Important Files to Reference

- **README.md**: User-facing documentation, quick start, examples
- **FUTURES.md**: Comprehensive futures/promises guide with patterns
- **CONTRIBUTING.md**: Coding standards, architecture guidelines, PR process
- **Package.swift**: SPM configuration, target structure

## Development Workflow

When implementing new features:
1. Determine if it belongs in PlugInKitProtocol (shared) or PlugInKit (host-only)
2. Follow Network.framework patterns: states, delegates, completion handlers
3. Use serial queues for state management
4. Add HeaderDoc comments for public APIs
5. Update relevant examples in Examples/
6. Consider both Objective-C and Swift usage patterns
7. Test with both async and sync XPC proxies
8. Update documentation (README.md or FUTURES.md) if adding significant features

## Common Gotchas

- Don't call synchronous XPC methods from main thread (causes deadlock)
- Don't modify connection/manager state from XPC callbacks (use dispatch_async to serial queue)
- Remember that futures transfer state across XPC but not callbacks
- Plugin discovery reads `PKXPCServiceName` from Info.plist, not CFBundleIdentifier
- Health polling only works when connection is in connected state
- Introspection requires plugin to implement `exposedMethodsWithReply:` correctly
