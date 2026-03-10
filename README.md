# swift-json-macros

Swift macros for JSON encoding and decoding using the new-codable API from [swift-foundation](https://github.com/apple/swift-foundation/tree/experimental/new-codable).

> [!NOTE]
> The macro implementation was done using Claude Opus 4.6 under human supervision.
> Use at your own risk.


## Usage

```swift
import JSONMacros

@JSONCodable
struct Market {
    var name: String
    var price: Double
    var isActive: Bool
    var tags: [String]
    var type: MarketType?
}
```

Use `@JSONDecodable` or `@JSONEncodable` separately if you only need one direction.

### Naming strategies

```swift
@JSONCodable(naming: .snakeCase)
struct User {
    var userName: String    // encodes as "user_name"
    var isActive: Bool      // encodes as "is_active"
}
```

### Custom keys

```swift
@JSONCodable
struct User {
    @JSONKey("user_name") var userName: String
    @JSONKey("is_active") var isActive: Bool
}
```

### Ignoring fields

Exclude properties from encoding and decoding:

```swift
@JSONCodable
struct Item {
    var name: String
    @JSONIgnore var cached: String = "default"
}
```

### Unknown fields

Capture unrecognized fields for round-trip fidelity:

```swift
@JSONCodable
struct Config {
    var name: String
    @JSONUnknownFields var unknownFields: [(key: String, value: JSONPrimitive)]
}
```

### Computed properties

Read-only computed properties are included in encoding and consumed during decoding.
This is useful for type discriminators in union types:

```swift
@JSONCodable
struct TextBlock {
    var type: String { "text" }  // encoded, consumed on decode
    var text: String
}
```

### Union types

Discriminated unions via `@JSONUnion`:

```swift
@JSONUnion("type")
enum ContentBlock {
    case text(TextBlock)
    @JSONCase("img")
    case image(ImageBlock)
    @JSONDefaultCase
    case unknown(JSONPrimitive)
}
```

- Case names are converted using the naming strategy (default: `.snakeCase`)
- Use `@JSONCase("name")` to override the discriminator value
- Use `@JSONCase("name1", "name2")` for multiple accepted values (first is used for encoding)
- Use `@JSONDefaultCase` to catch unknown discriminator values

## Requirements

- Swift 6.3+
- [swift-foundation](https://github.com/apple/swift-foundation) (experimental/new-codable branch)

## Installation

```swift
.package(url: "https://github.com/t089/swift-json-macros", branch: "main")
```

```swift
.target(name: "YourTarget", dependencies: [
    .product(name: "JSONMacros", package: "swift-json-macros"),
])
```

## License

Copyright 2026 Tobias Haeberle

Licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE) for details.
