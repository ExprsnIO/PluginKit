//
//  PlugInKitSwift.swift
//  PlugInKit
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

import Foundation

// MARK: - Swift Extensions for PlugInKit

/// Swift-friendly extension for PKPlugInManager
@available(macOS 10.15, *)
extension PKPlugInManager {
    /// Discover plugins using async/await
    @available(macOS 12.0, *)
    public func discoverPlugIns() async throws -> [PKPlugInInfo] {
        try await withCheckedThrowingContinuation { continuation in
            discoverPlugIns { plugIns, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: plugIns)
                }
            }
        }
    }

    /// Connect to plugin using async/await
    @available(macOS 12.0, *)
    public func connect(to identifier: String,
                       configuration: [String: Any]? = nil) async throws -> PKConnection {
        try await withCheckedThrowingContinuation { continuation in
            connectToPlugIn(identifier, configuration: configuration) { connection, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let connection = connection {
                    continuation.resume(returning: connection)
                } else {
                    continuation.resume(throwing: PKError.connectionFailed)
                }
            }
        }
    }

    /// Broadcast message using async/await
    @available(macOS 12.0, *)
    public func broadcast(message: [String: Any]) async -> [String: Any] {
        await withCheckedContinuation { continuation in
            broadcastMessage(message) { responses in
                continuation.resume(returning: responses)
            }
        }
    }
}

/// Swift-friendly extension for PKConnection
@available(macOS 10.15, *)
extension PKConnection {
    /// Poll connection using async/await
    @available(macOS 12.0, *)
    public func poll() async throws -> (success: Bool, latency: TimeInterval) {
        try await withCheckedThrowingContinuation { continuation in
            poll { success, latency, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (success, latency))
                }
            }
        }
    }
}

/// Swift-friendly extension for PKIntrospector
@available(macOS 10.15, *)
extension PKIntrospector {
    /// Introspect connection using async/await
    @available(macOS 12.0, *)
    public static func introspect(connection: PKConnection) async throws -> PKIntrospectionResult {
        try await withCheckedThrowingContinuation { continuation in
            introspectConnection(connection) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let result = result {
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(throwing: PKError.introspectionFailed)
                }
            }
        }
    }

    /// Introspect multiple connections using async/await
    @available(macOS 12.0, *)
    public static func introspect(connections: [PKConnection]) async throws -> [PKIntrospectionResult] {
        try await withCheckedThrowingContinuation { continuation in
            introspectConnections(connections) { results, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: results)
                }
            }
        }
    }
}

// MARK: - Swift Error Type

/// PlugInKit errors
public enum PKError: Error, LocalizedError {
    case connectionFailed
    case introspectionFailed
    case plugInNotFound(String)
    case invalidConfiguration
    case communicationError(Error)

    public var errorDescription: String? {
        switch self {
        case .connectionFailed:
            return "Failed to establish plugin connection"
        case .introspectionFailed:
            return "Failed to introspect plugin"
        case .plugInNotFound(let identifier):
            return "Plugin not found: \(identifier)"
        case .invalidConfiguration:
            return "Invalid plugin configuration"
        case .communicationError(let error):
            return "Communication error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Swift-friendly Enums

extension PKXPCConnectionState: CustomStringConvertible {
    public var description: String {
        switch self {
        case .disconnected: return "disconnected"
        case .connecting: return "connecting"
        case .connected: return "connected"
        case .interrupted: return "interrupted"
        case .invalidated: return "invalidated"
        @unknown default: return "unknown"
        }
    }
}

extension PKConnectionHealth: CustomStringConvertible {
    public var description: String {
        switch self {
        case .unknown: return "unknown"
        case .healthy: return "healthy"
        case .degraded: return "degraded"
        case .unhealthy: return "unhealthy"
        @unknown default: return "unknown"
        }
    }
}

extension PKMethodExposureOptions {
    public static let none = PKMethodExposureOptions(rawValue: 0)
    public static let appleScript = PKMethodExposureOptions.appleScript
    public static let javaScript = PKMethodExposureOptions.javaScript
    public static let all = PKMethodExposureOptions.all

    public var description: String {
        var parts: [String] = []
        if contains(.appleScript) { parts.append("AppleScript") }
        if contains(.javaScript) { parts.append("JavaScript") }
        return parts.isEmpty ? "none" : parts.joined(separator: ", ")
    }
}

// MARK: - Swift Protocol Helpers

/// Swift protocol for plugin implementation
@available(macOS 10.15, *)
public protocol SwiftPlugInProtocol: PKPlugInProtocol {
    @available(macOS 12.0, *)
    func initialize(configuration: [String: Any]) async throws

    @available(macOS 12.0, *)
    func exposedMethods() async -> [PKMethodMetadata]

    @available(macOS 12.0, *)
    func prepareForTermination() async

    @available(macOS 12.0, *)
    func handleMessage(_ message: [String: Any]) async throws -> [String: Any]

    @available(macOS 12.0, *)
    func capabilities() async -> [String: Any]
}

/// Default implementations for Swift plugins
@available(macOS 10.15, *)
extension SwiftPlugInProtocol {
    public func initialize(withConfiguration configuration: [String: Any],
                          reply: @escaping (Error?) -> Void) {
        if #available(macOS 12.0, *) {
            Task {
                do {
                    try await initialize(configuration: configuration)
                    reply(nil)
                } catch {
                    reply(error)
                }
            }
        } else {
            reply(PKError.invalidConfiguration)
        }
    }

    public func exposedMethods(reply: @escaping ([PKMethodMetadata]) -> Void) {
        if #available(macOS 12.0, *) {
            Task {
                let methods = await exposedMethods()
                reply(methods)
            }
        } else {
            reply([])
        }
    }

    public func prepareForTermination(reply: @escaping () -> Void) {
        if #available(macOS 12.0, *) {
            Task {
                await prepareForTermination()
                reply()
            }
        } else {
            reply()
        }
    }

    public func handle(_ message: [String: Any],
                      reply: @escaping ([String: Any]?, Error?) -> Void) {
        if #available(macOS 12.0, *) {
            Task {
                do {
                    let response = try await handleMessage(message)
                    reply(response, nil)
                } catch {
                    reply(nil, error)
                }
            }
        } else {
            reply(nil, PKError.invalidConfiguration)
        }
    }

    public func capabilities(reply: @escaping ([String: Any]) -> Void) {
        if #available(macOS 12.0, *) {
            Task {
                let caps = await capabilities()
                reply(caps)
            }
        } else {
            reply([:])
        }
    }
}

// MARK: - Builder Pattern for Method Metadata

@available(macOS 10.15, *)
extension PKMethodMetadata {
    /// Builder for creating method metadata
    public final class Builder {
        private var selector: String
        private var displayName: String
        private var description: String?
        private var exposureOptions: PKMethodExposureOptions = .none
        private var parameterTypes: [String] = []
        private var returnType: String = "v"

        public init(selector: String, displayName: String) {
            self.selector = selector
            self.displayName = displayName
        }

        public func description(_ description: String) -> Builder {
            self.description = description
            return self
        }

        public func exposedTo(_ options: PKMethodExposureOptions) -> Builder {
            self.exposureOptions = options
            return self
        }

        public func parameters(_ types: [String]) -> Builder {
            self.parameterTypes = types
            return self
        }

        public func returns(_ type: String) -> Builder {
            self.returnType = type
            return self
        }

        public func build() -> PKMethodMetadata {
            PKMethodMetadata(
                selector: selector,
                displayName: displayName,
                description: description,
                exposureOptions: exposureOptions,
                parameterTypes: parameterTypes,
                returnType: returnType
            )
        }
    }

    public static func builder(selector: String, displayName: String) -> Builder {
        Builder(selector: selector, displayName: displayName)
    }
}

// MARK: - Convenience Extensions

@available(macOS 10.15, *)
extension PKIntrospectionResult {
    /// Get methods exposed to AppleScript
    public var appleScriptMethods: [PKMethodMetadata] {
        methods(withExposureOptions: PKMethodExposureAppleScript.rawValue)
    }

    /// Get methods exposed to JavaScript
    public var javaScriptMethods: [PKMethodMetadata] {
        methods(withExposureOptions: PKMethodExposureJavaScript.rawValue)
    }

    /// Get all publicly exposed methods
    public var publicMethods: [PKMethodMetadata] {
        methods(withExposureOptions: PKMethodExposureAll.rawValue)
    }
}

@available(macOS 10.15, *)
extension PKPlugInInfo: Identifiable {
    public var id: String { identifier }
}
