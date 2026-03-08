import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

@testable import JSONMacrosPlugin

private let testMacros: [String: Macro.Type] = [
  "JSONDecodable": JSONDecodableMacro.self,
  "JSONKey": JSONKeyMacro.self,
  "JSONUnknownFields": JSONUnknownFieldsMacro.self,
]

@Suite("JSONDecodable macro")
struct JSONDecodableTests {
  @Test func basicStruct() {
    assertMacroExpansion(
      """
      @JSONDecodable
      struct Market {
          var name: String
          var price: Double
          var isActive: Bool
      }
      """,
      expandedSource: """
        struct Market {
            var name: String
            var price: Double
            var isActive: Bool

            static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
                try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var name: String?
                    var price: Double?
                    var isActive: Bool?
                    try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                        switch key {
                        case "name": name = try valueDecoder.decode(String.self)
                        case "price": price = try valueDecoder.decode(Double.self)
                        case "isActive": isActive = try valueDecoder.decode(Bool.self)
                        default: break
                        }
                        return false
                    }
                    return Market(
                        name: try name.unwrap(key: "name"),
                        price: try price.unwrap(key: "price"),
                        isActive: try isActive.unwrap(key: "isActive")
                    )
                }
            }
        }

        extension Market: JSONDecodable {
        }
        """,
      macros: testMacros
    )
  }

  @Test func optionalProperties() {
    assertMacroExpansion(
      """
      @JSONDecodable
      struct User {
          var name: String
          var bio: String?
          var age: Optional<Int>
      }
      """,
      expandedSource: """
        struct User {
            var name: String
            var bio: String?
            var age: Optional<Int>

            static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
                try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var name: String?
                    var bio: String??
                    var age: Optional<Int>?
                    try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                        switch key {
                        case "name": name = try valueDecoder.decode(String.self)
                        case "bio": bio = try valueDecoder.decode(String.self)
                        case "age": age = try valueDecoder.decode(Int.self)
                        default: break
                        }
                        return false
                    }
                    return User(
                        name: try name.unwrap(key: "name"),
                        bio: bio ?? nil,
                        age: age ?? nil
                    )
                }
            }
        }

        extension User: JSONDecodable {
        }
        """,
      macros: testMacros
    )
  }

  @Test func customKeys() {
    assertMacroExpansion(
      """
      @JSONDecodable
      struct User {
          @JSONKey("user_name") var userName: String
          @JSONKey("is_active") var isActive: Bool
      }
      """,
      expandedSource: """
        struct User {
            var userName: String
            var isActive: Bool

            static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
                try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var userName: String?
                    var isActive: Bool?
                    try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                        switch key {
                        case "user_name": userName = try valueDecoder.decode(String.self)
                        case "is_active": isActive = try valueDecoder.decode(Bool.self)
                        default: break
                        }
                        return false
                    }
                    return User(
                        userName: try userName.unwrap(key: "user_name"),
                        isActive: try isActive.unwrap(key: "is_active")
                    )
                }
            }
        }

        extension User: JSONDecodable {
        }
        """,
      macros: testMacros
    )
  }

  @Test func appliedToEnum() {
    assertMacroExpansion(
      """
      @JSONDecodable
      enum Foo {
          case a
      }
      """,
      expandedSource: """
        enum Foo {
            case a
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "@JSONDecodable / @JSONEncodable can only be applied to structs or classes",
          line: 1,
          column: 1
        )
      ],
      macros: testMacros
    )
  }

  @Test func skipsComputedProperties() {
    assertMacroExpansion(
      """
      @JSONDecodable
      struct Item {
          var name: String
          var displayName: String {
              name.uppercased()
          }
      }
      """,
      expandedSource: """
        struct Item {
            var name: String
            var displayName: String {
                name.uppercased()
            }

            static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
                try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var name: String?
                    try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                        switch key {
                        case "name": name = try valueDecoder.decode(String.self)
                        default: break
                        }
                        return false
                    }
                    return Item(
                        name: try name.unwrap(key: "name")
                    )
                }
            }
        }

        extension Item: JSONDecodable {
        }
        """,
      macros: testMacros
    )
  }

  @Test func unknownFields() {
    assertMacroExpansion(
      """
      @JSONDecodable
      struct Market {
          var name: String
          @JSONUnknownFields var unknownFields: [(key: String, value: JSONPrimitive)]
      }
      """,
      expandedSource: """
        struct Market {
            var name: String
            var unknownFields: [(key: String, value: JSONPrimitive)]

            static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
                try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var name: String?
                    var unknownFields: [(key: String, value: JSONPrimitive)] = []
                    try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                        switch key {
                        case "name": name = try valueDecoder.decode(String.self)
                        default: unknownFields.append((key: key, value: try valueDecoder.decode(JSONPrimitive.self)))
                        }
                        return false
                    }
                    return Market(
                        name: try name.unwrap(key: "name"),
                        unknownFields: unknownFields
                    )
                }
            }
        }

        extension Market: JSONDecodable {
        }
        """,
      macros: testMacros
    )
  }

  @Test func snakeCaseNaming() {
    assertMacroExpansion(
      """
      @JSONDecodable(naming: .snakeCase)
      struct User {
          var userName: String
          var isActive: Bool
      }
      """,
      expandedSource: """
        struct User {
            var userName: String
            var isActive: Bool

            static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
                try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var userName: String?
                    var isActive: Bool?
                    try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                        switch key {
                        case "user_name": userName = try valueDecoder.decode(String.self)
                        case "is_active": isActive = try valueDecoder.decode(Bool.self)
                        default: break
                        }
                        return false
                    }
                    return User(
                        userName: try userName.unwrap(key: "user_name"),
                        isActive: try isActive.unwrap(key: "is_active")
                    )
                }
            }
        }

        extension User: JSONDecodable {
        }
        """,
      macros: testMacros
    )
  }

  @Test func snakeCaseWithKeyOverride() {
    assertMacroExpansion(
      """
      @JSONDecodable(naming: .snakeCase)
      struct User {
          var userName: String
          @JSONKey("active") var isActive: Bool
      }
      """,
      expandedSource: """
        struct User {
            var userName: String
            var isActive: Bool

            static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
                try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var userName: String?
                    var isActive: Bool?
                    try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                        switch key {
                        case "user_name": userName = try valueDecoder.decode(String.self)
                        case "active": isActive = try valueDecoder.decode(Bool.self)
                        default: break
                        }
                        return false
                    }
                    return User(
                        userName: try userName.unwrap(key: "user_name"),
                        isActive: try isActive.unwrap(key: "active")
                    )
                }
            }
        }

        extension User: JSONDecodable {
        }
        """,
      macros: testMacros
    )
  }
}
