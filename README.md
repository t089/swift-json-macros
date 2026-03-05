# swift-json-macros

Swift macros for JSON encoding and decoding using [swift-json](https://github.com/tayloraswift/swift-json).

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

### Custom keys

```swift
@JSONCodable
struct User {
    @JSONKey("user_name") var userName: String
    @JSONKey("is_active") var isActive: Bool
}
```

### Unknown fields

Capture unrecognized fields for round-trip fidelity:

```swift
@JSONCodable
struct Config {
    var name: String
    @JSONUnknownFields var unknownFields: JSON.Object
}
```

### Arbitrary JSON

Store arbitrary JSON values using `JSON.Node`, `JSON.Object`, or `JSON.Array`:

```swift
@JSONCodable
struct Event {
    var type: String
    var metadata: JSON.Node
}
```

## Requirements

- Swift 6.2+
- [swift-json](https://github.com/tayloraswift/swift-json) 2.3.0+

## Installation

```swift
.package(url: "https://github.com/yourname/swift-json-macros", from: "1.0.0")
```

```swift
.target(name: "YourTarget", dependencies: [
    .product(name: "JSONMacros", package: "swift-json-macros"),
])
```
