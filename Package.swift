// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "afmbridge",
    platforms: [
        // NOTE: FoundationModels framework requires macOS 26.0+ when available
        // Using macOS 15.0 for now as the build target
        .macOS(.v15)
    ],
    products: [
        .executable(
            name: "AFMBridge",
            targets: ["App"]
        )
    ],
    dependencies: [
        // Vapor 4.x - Swift web framework
        .package(url: "https://github.com/vapor/vapor.git", from: "4.99.0"),
        // Swift log for structured logging
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0")
    ],
    targets: [
        // Executable target - App entry point
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Logging", package: "swift-log"),
                "Controllers",
                "Configuration"
            ],
            path: "Sources/App"
        ),

        // Controllers - HTTP request handlers
        .target(
            name: "Controllers",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                "DTOs",
                "Services"
            ],
            path: "Sources/Controllers"
        ),

        // DTOs - Data Transfer Objects
        .target(
            name: "DTOs",
            dependencies: [
                .product(name: "Vapor", package: "vapor")
            ],
            path: "Sources/DTOs"
        ),

        // Services - Business logic
        .target(
            name: "Services",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
                "DTOs",
                "Models"
            ],
            path: "Sources/Services"
        ),

        // Models - Domain models and errors
        .target(
            name: "Models",
            dependencies: [],
            path: "Sources/Models"
        ),

        // Middleware - Request/response processing
        .target(
            name: "Middleware",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                "Configuration"
            ],
            path: "Sources/Middleware"
        ),

        // Configuration - Server configuration
        .target(
            name: "Configuration",
            dependencies: [
                .product(name: "Vapor", package: "vapor")
            ],
            path: "Sources/Configuration"
        ),

        // Tests
        .testTarget(
            name: "AppTests",
            dependencies: [
                .product(name: "XCTVapor", package: "vapor"),
                "App",
                "Controllers",
                "DTOs",
                "Services",
                "Models",
                "Middleware",
                "Configuration"
            ],
            path: "Tests/AppTests"
        )
    ],
    swiftLanguageModes: [.v6]
)
