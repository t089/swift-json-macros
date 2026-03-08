// swift-tools-version: 6.3

import CompilerPluginSupport
import PackageDescription

let package = Package(
  name: "swift-json-macros",
  products: [
    .library(
      name: "JSONMacros",
      targets: ["JSONMacros"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/swiftlang/swift-syntax", from: "602.0.0"),
    .package(
      url: "https://github.com/apple/swift-foundation.git",
      branch: "experimental/new-codable"
    ),
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
        .product(name: "NewCodable", package: "swift-foundation"),
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
