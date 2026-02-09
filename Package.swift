// swift-tools-version: 5.9
// =============================================================================
// Package.swift — mSCP CNSSI-1253 Baseline Tools
// =============================================================================
//
// Open this file in Xcode (File → Open…) to build and run the tools.
//
// Targets:
//   cnssi-baseline-generator  – Full baseline generation workflow
//   cnssi-merge               – Merge CNSSI tags into mSCP rule files
//
// Both are pure-Foundation command-line tools with no external dependencies.
// =============================================================================

import PackageDescription

let package = Package(
    name: "macos_security_cnssi",

    platforms: [
        .macOS(.v13)
    ],

    targets: [
        .executableTarget(
            name: "cnssi-baseline-generator",
            path: "Sources/cnssi-baseline-generator"
        ),
        .executableTarget(
            name: "cnssi-merge",
            path: "Sources/cnssi-merge"
        ),
    ]
)
