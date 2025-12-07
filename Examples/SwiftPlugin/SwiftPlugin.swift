//
//  SwiftPlugin.swift
//  SwiftPlugin
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

import Foundation
import PlugInKit

/// Example Swift plugin implementation
@available(macOS 10.15, *)
@objc public class SwiftPlugin: NSObject, PKPlugInProtocol {

    @objc public var plugInIdentifier: String { "com.example.swiftplugin" }
    @objc public var plugInVersion: String { "1.0.0" }
    @objc public var plugInDisplayName: String { "Swift Plugin" }

    private var configuration: [String: Any] = [:]

    // MARK: - PKPlugInProtocol

    @objc public func initialize(withConfiguration configuration: [String: Any],
                                 reply: @escaping (Error?) -> Void) {
        print("[SwiftPlugin] Initializing with configuration: \(configuration)")
        self.configuration = configuration

        // Simulate async initialization
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            reply(nil)
        }
    }

    @objc public func prepareForTermination(reply: @escaping () -> Void) {
        print("[SwiftPlugin] Preparing for termination")
        configuration.removeAll()
        reply()
    }

    @objc public func exposedMethods(reply: @escaping ([PKMethodMetadata]) -> Void) {
        let methods: [PKMethodMetadata] = [
            // Method 1: Transform text
            PKMethodMetadata.builder(selector: "transformText:options:reply:",
                                    displayName: "Transform Text")
                .description("Transforms text with various options")
                .exposedTo(.all)
                .parameters(["@\"NSString\"", "@\"NSDictionary\""])
                .returns("@\"NSString\"")
                .build(),

            // Method 2: Analyze data
            PKMethodMetadata.builder(selector: "analyzeData:reply:",
                                    displayName: "Analyze Data")
                .description("Analyzes input data and returns statistics")
                .exposedTo(.appleScript)
                .parameters(["@\"NSArray\""])
                .returns("@\"NSDictionary\"")
                .build(),

            // Method 3: Generate report (JavaScript only)
            PKMethodMetadata.builder(selector: "generateReport:reply:",
                                    displayName: "Generate Report")
                .description("Generates a report from data")
                .exposedTo(.javaScript)
                .parameters(["@\"NSDictionary\""])
                .returns("@\"NSString\"")
                .build(),

            // Method 4: Internal helper
            PKMethodMetadata.builder(selector: "helperMethod:reply:",
                                    displayName: "Helper Method")
                .description("Internal helper method")
                .exposedTo(.none)
                .parameters(["@\"NSString\""])
                .returns("v")
                .build()
        ]

        reply(methods)
    }

    @objc public func handleMessage(_ message: [String: Any],
                                   reply: @escaping ([String: Any]?, Error?) -> Void) {
        print("[SwiftPlugin] Received message: \(message)")

        guard let action = message["action"] as? String else {
            let error = NSError(domain: "com.example.swiftplugin",
                              code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "Missing action"])
            reply(nil, error)
            return
        }

        switch action {
        case "ping":
            reply(["status": "pong", "timestamp": Date()], nil)

        case "info":
            reply([
                "identifier": plugInIdentifier,
                "version": plugInVersion,
                "name": plugInDisplayName
            ], nil)

        default:
            let error = NSError(domain: "com.example.swiftplugin",
                              code: 2,
                              userInfo: [NSLocalizedDescriptionKey: "Unknown action: \(action)"])
            reply(nil, error)
        }
    }

    @objc public func hostStateDidChange(_ state: [String: Any]) {
        print("[SwiftPlugin] Host state changed: \(state)")
    }

    @objc public func capabilities(reply: @escaping ([String: Any]) -> Void) {
        reply([
            "supportsTextTransformation": true,
            "supportsDataAnalysis": true,
            "supportsReportGeneration": true,
            "version": plugInVersion,
            "platform": "Swift",
            "features": ["transform", "analyze", "report"]
        ])
    }

    // MARK: - Plugin Methods

    @objc public func transformText(_ text: String,
                                   options: [String: Any],
                                   reply: @escaping (String) -> Void) {
        print("[SwiftPlugin] Transforming text: \(text) with options: \(options)")

        var result = text

        if let uppercase = options["uppercase"] as? Bool, uppercase {
            result = result.uppercased()
        }

        if let reverse = options["reverse"] as? Bool, reverse {
            result = String(result.reversed())
        }

        if let prefix = options["prefix"] as? String {
            result = prefix + result
        }

        reply(result)
    }

    @objc public func analyzeData(_ data: [Any],
                                 reply: @escaping ([String: Any]) -> Void) {
        print("[SwiftPlugin] Analyzing data: \(data)")

        let numbers = data.compactMap { $0 as? Double }

        guard !numbers.isEmpty else {
            reply(["error": "No numeric data found"])
            return
        }

        let sum = numbers.reduce(0, +)
        let average = sum / Double(numbers.count)
        let min = numbers.min() ?? 0
        let max = numbers.max() ?? 0

        reply([
            "count": numbers.count,
            "sum": sum,
            "average": average,
            "min": min,
            "max": max
        ])
    }

    @objc public func generateReport(_ data: [String: Any],
                                    reply: @escaping (String) -> Void) {
        print("[SwiftPlugin] Generating report from: \(data)")

        var report = "=== Report ===\n"
        report += "Generated: \(Date())\n\n"

        for (key, value) in data {
            report += "\(key): \(value)\n"
        }

        reply(report)
    }

    @objc public func helperMethod(_ input: String,
                                  reply: @escaping () -> Void) {
        print("[SwiftPlugin] Helper method called with: \(input)")
        // Internal processing
        reply()
    }
}

// MARK: - Async/Await Support

@available(macOS 12.0, *)
extension SwiftPlugin: SwiftPlugInProtocol {

    public func initialize(configuration: [String: Any]) async throws {
        self.configuration = configuration
        print("[SwiftPlugin] Async initialization with: \(configuration)")
    }

    public func exposedMethods() async -> [PKMethodMetadata] {
        await withCheckedContinuation { continuation in
            exposedMethods { methods in
                continuation.resume(returning: methods)
            }
        }
    }

    public func prepareForTermination() async {
        print("[SwiftPlugin] Async termination")
        configuration.removeAll()
    }

    public func handleMessage(_ message: [String: Any]) async throws -> [String: Any] {
        try await withCheckedThrowingContinuation { continuation in
            handleMessage(message) { response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: response ?? [:])
                }
            }
        }
    }

    public func capabilities() async -> [String: Any] {
        await withCheckedContinuation { continuation in
            capabilities { caps in
                continuation.resume(returning: caps)
            }
        }
    }
}
