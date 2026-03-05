// swift-tools-version: 6.2

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "swift-json-macros",
    products: [
        .library(
            name: "JSONMacros",
            targets: ["JSONMacros"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax", from: "602.0.0"),
        .package(url: "https://github.com/tayloraswift/swift-json", from: "2.3.0"),
    ],
    targets: [
        .macro(
            name: "JSONMacrosPlugin",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "JSONMacros",
            dependencies: [
                "JSONMacrosPlugin",
                .product(name: "JSON", package: "swift-json"),
            ]
        ),
        .testTarget(
            name: "JSONMacrosTests",
            dependencies: [
                "JSONMacros",
                "JSONMacrosPlugin",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ]
)
