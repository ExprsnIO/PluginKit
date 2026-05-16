// swift-tools-version:5.5
//
//  Package.swift
//  PlugInKit
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

import PackageDescription

let package = Package(
    name: "PlugInKit",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "PlugInKit",
            targets: ["PlugInKit"]),
        .library(
            name: "PlugInKitProtocol",
            targets: ["PlugInKitProtocol"]),
    ],
    targets: [
        // Main framework target
        .target(
            name: "PlugInKit",
            dependencies: ["PlugInKitProtocol"],
            path: "Sources/PlugInKit",
            publicHeadersPath: ".",
            cSettings: [
                .headerSearchPath("."),
                .headerSearchPath("Core"),
                .headerSearchPath("XPC"),
                .headerSearchPath("Introspection"),
                .headerSearchPath("ScriptingBridge"),
            ],
            cxxSettings: [
                .headerSearchPath("."),
                .headerSearchPath("ScriptingBridge"),
                .define("__STDC_CONSTANT_MACROS"),
                .define("__STDC_LIMIT_MACROS"),
            ],
            linkerSettings: [
                .linkedLibrary("c++")
            ]
        ),

        // Protocol library (shared between host and plugins)
        .target(
            name: "PlugInKitProtocol",
            path: "Sources/PlugInKitProtocol",
            publicHeadersPath: "."
        ),

        // Unit tests for the host framework
        .testTarget(
            name: "PlugInKitTests",
            dependencies: ["PlugInKit", "PlugInKitProtocol"],
            path: "Tests/PlugInKitTests"
        ),
    ]
)
