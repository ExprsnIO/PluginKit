//
//  main.swift
//  SwiftHostApp
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

import Foundation
import PlugInKit

@available(macOS 10.15, *)
class SwiftHostApp: NSObject, PKPlugInManagerDelegate, PKConnectionDelegate {

    let manager = PKPlugInManager.shared()

    func run() {
        print("=== PlugInKit Swift Host Application ===\n")

        manager.delegate = self
        manager.pollingEnabled = true
        manager.defaultPollingInterval = 3.0

        discoverAndConnectPlugins()

        RunLoop.main.run()
    }

    func discoverAndConnectPlugins() {
        print("Discovering plugins...")

        manager.discoverPlugIns { [weak self] plugIns, error in
            guard let self = self else { return }

            if let error = error {
                print("Error discovering plugins: \(error)")
                self.demonstrateAPI()
                return
            }

            print("Found \(plugIns.count) plugin(s):")
            for info in plugIns {
                print("  - \(info.name) (\(info.identifier)) v\(info.version)")
            }

            if let first = plugIns.first {
                self.connect(to: first)
            } else {
                print("\nNo plugins found. This is expected in example mode.")
                self.demonstrateAPI()
            }
        }
    }

    func connect(to plugInInfo: PKPlugInInfo) {
        print("\nConnecting to plugin: \(plugInInfo.identifier)")

        let config: [String: Any] = [
            "mode": "production",
            "debug": true
        ]

        manager.connectToPlugIn(plugInInfo.identifier,
                               configuration: config) { [weak self] connection, error in
            guard let self = self else { return }

            if let error = error {
                print("Failed to connect: \(error)")
                return
            }

            guard let connection = connection else {
                print("Connection is nil")
                return
            }

            print("Successfully connected!")
            connection.delegate = self

            self.test(connection: connection)
        }
    }

    func test(connection: PKConnection) {
        print("\n=== Testing Plugin Connection ===")

        let plugin = connection.remotePlugIn { error in
            print("Error getting remote plugin: \(error)")
        }

        // Test capabilities
        if plugin.responds(to: #selector(PKPlugInProtocol.capabilities(reply:))) {
            plugin.capabilities { capabilities in
                print("\nPlugin Capabilities:")
                for (key, value) in capabilities {
                    print("  \(key): \(value)")
                }

                self.introspect(connection: connection)
            }
        } else {
            introspect(connection: connection)
        }
    }

    func introspect(connection: PKConnection) {
        print("\n=== Introspecting Plugin ===")

        PKIntrospector.introspectConnection(connection) { [weak self] result, error in
            guard let self = self else { return }

            if let error = error {
                print("Introspection error: \(error)")
                return
            }

            guard let result = result else {
                print("No introspection result")
                return
            }

            print("Found \(result.methods.count) exposed methods:")

            for method in result.methods {
                print("\n  Method: \(method.displayName)")
                print("    Selector: \(method.selector)")
                print("    Description: \(method.methodDescription ?? "N/A")")

                let appleScript = (method.exposureOptions & PKMethodExposureAppleScript.rawValue) != 0
                let javaScript = (method.exposureOptions & PKMethodExposureJavaScript.rawValue) != 0

                print("    Exposure: AppleScript=\(appleScript) JavaScript=\(javaScript)")
                print("    Signature: \(PKIntrospector.signature(for: method))")
            }

            self.generateScriptingDefinitions(result: result)
            self.testMessaging(connection: connection)
        }
    }

    func generateScriptingDefinitions(result: PKIntrospectionResult) {
        print("\n=== Generating Scripting Definitions ===")

        // AppleScript
        let applescript = PKScriptingDefinitionGenerator.generateDefinition(
            fromIntrospectionResult: result,
            format: .appleScript,
            options: .verbose
        )
        print("\nAppleScript Definition:\n\(applescript)")

        // JavaScript
        let javascript = PKScriptingDefinitionGenerator.generateDefinition(
            fromIntrospectionResult: result,
            format: .javaScript,
            options: .includeTypes
        )
        print("\nJavaScript Definition:\n\(javascript)")

        // SDEF
        let sdef = PKScriptingDefinitionGenerator.generateSDEF(
            fromIntrospectionResults: [result],
            suiteName: "Example",
            options: .none
        )
        print("\nSDEF Definition:\n\(sdef)")
    }

    func testMessaging(connection: PKConnection) {
        print("\n=== Testing Bidirectional Communication ===")

        let plugin = connection.remotePlugIn { error in
            print("Error: \(error)")
        }

        if plugin.responds(to: #selector(PKPlugInProtocol.handle(_:reply:))) {
            let message: [String: Any] = [
                "action": "ping",
                "timestamp": Date()
            ]

            plugin.handle(message) { response, error in
                if let error = error {
                    print("Message error: \(error)")
                } else {
                    print("Message response: \(response ?? [:])")
                }

                self.testPolling(connection: connection)
            }
        } else {
            testPolling(connection: connection)
        }
    }

    func testPolling(connection: PKConnection) {
        print("\n=== Testing Connection Polling ===")
        print("Polling enabled: \(connection.isPollingEnabled)")
        print("Polling interval: \(connection.pollingInterval) seconds")

        connection.poll { success, latency, error in
            if success {
                print("Poll successful! Latency: \(String(format: "%.3f", latency)) seconds")
                print("Connection health: \(connection.health)")
                print("Average latency: \(String(format: "%.3f", connection.averageLatency)) seconds")
            } else {
                print("Poll failed: \(error?.localizedDescription ?? "unknown error")")
            }

            print("\n=== Test Complete ===")
        }
    }

    func demonstrateAPI() {
        print("\n=== PlugInKit Swift API Usage Examples ===\n")

        print("1. Plugin Discovery:")
        print("   manager.discoverPlugIns { plugIns, error in")
        print("       // Handle discovered plugins")
        print("   }")

        print("\n2. Connect to Plugin:")
        print("   manager.connectToPlugIn(identifier,")
        print("                          configuration: config) { connection, error in")
        print("       // Use connection")
        print("   }")

        print("\n3. Introspect Plugin:")
        print("   PKIntrospector.introspectConnection(connection) { result, error in")
        print("       // Analyze methods and capabilities")
        print("   }")

        print("\n4. Generate Scripting Definitions:")
        print("   let def = PKScriptingDefinitionGenerator.generateDefinition(")
        print("       fromIntrospectionResult: result,")
        print("       format: .appleScript,")
        print("       options: .verbose)")

        print("\n5. Connection Health Monitoring:")
        print("   connection.pollingEnabled = true")
        print("   connection.pollingInterval = 5.0")
        print("   // Automatic health monitoring")

        if #available(macOS 12.0, *) {
            print("\n6. Async/Await Support (macOS 12.0+):")
            print("   Task {")
            print("       let plugIns = try await manager.discoverPlugIns()")
            print("       let connection = try await manager.connect(to: identifier)")
            print("       let result = try await PKIntrospector.introspect(connection: connection)")
            print("   }")
        }
    }

    // MARK: - PKPlugInManagerDelegate

    func plugInManager(_ manager: PKPlugInManager, didDiscover plugInInfo: PKPlugInInfo) {
        print("[Delegate] Discovered plugin: \(plugInInfo.name)")
    }

    func plugInManager(_ manager: PKPlugInManager, didEstablishConnection connection: PKConnection) {
        print("[Delegate] Established connection to: \(connection.plugInIdentifier)")
    }

    func plugInManager(_ manager: PKPlugInManager,
                      didFailToConnectToPlugIn identifier: String,
                      error: Error) {
        print("[Delegate] Failed to connect to \(identifier): \(error)")
    }

    // MARK: - PKConnectionDelegate

    func connection(_ connection: PKConnection, didChangeHealth health: PKConnectionHealth) {
        print("[Delegate] Connection \(connection.plugInIdentifier) health changed to: \(health)")
    }

    func connection(_ connection: PKConnection, didChangeState state: PKXPCConnectionState) {
        print("[Delegate] Connection \(connection.plugInIdentifier) state changed to: \(state)")
    }

    func connection(_ connection: PKConnection,
                   didCompletePoll success: Bool,
                   latency: TimeInterval) {
        let status = success ? "succeeded" : "failed"
        print("[Delegate] Poll \(status) - latency: \(String(format: "%.3f", latency))s")
    }
}

// MARK: - Async/Await Example

@available(macOS 12.0, *)
extension SwiftHostApp {
    func runAsync() async {
        print("\n=== Using Async/Await API ===\n")

        do {
            // Discover plugins
            let plugIns = try await manager.discoverPlugIns()
            print("Found \(plugIns.count) plugin(s)")

            guard let first = plugIns.first else {
                print("No plugins found")
                return
            }

            // Connect
            let connection = try await manager.connect(to: first.identifier, configuration: [:])
            print("Connected to \(connection.plugInIdentifier)")

            // Introspect
            let result = try await PKIntrospector.introspect(connection: connection)
            print("Introspected \(result.methods.count) methods")

            // Poll
            let (success, latency) = try await connection.poll()
            print("Poll \(success ? "succeeded" : "failed") - latency: \(latency)s")

        } catch {
            print("Error: \(error)")
        }
    }
}

// MARK: - Main Entry Point

if #available(macOS 10.15, *) {
    let app = SwiftHostApp()

    if #available(macOS 12.0, *) {
        Task {
            await app.runAsync()
        }
    }

    app.run()
} else {
    print("PlugInKit requires macOS 10.15 or later")
}
