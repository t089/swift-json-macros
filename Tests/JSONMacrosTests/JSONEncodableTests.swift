import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

@testable import JSONMacrosPlugin

private let testMacros: [String: Macro.Type] = [
  "JSONEncodable": JSONEncodableMacro.self,
  "JSONKey": JSONKeyMacro.self,
  "JSONUnknownFields": JSONUnknownFieldsMacro.self,
]

@Suite("JSONEncodable macro")
struct JSONEncodableTests {
  @Test func basicStruct() {
    assertMacroExpansion(
      """
      @JSONEncodable
      struct Market {
          var name: String
          var price: Double
      }
      """,
      expandedSource: """
        struct Market {
            var name: String
            var price: Double

            func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                try encoder.encodeStructFields(count: nil) { structEncoder throws(CodingError.Encoding) in
                    try structEncoder.encode(key: "name", value: self.name)
                    try structEncoder.encode(key: "price", value: self.price)
                }
            }
        }

        extension Market: JSONEncodable {
        }
        """,
      macros: testMacros
    )
  }

  @Test func optionalProperties() {
    assertMacroExpansion(
      """
      @JSONEncodable
      struct User {
          var name: String
          var bio: String?
      }
      """,
      expandedSource: """
        struct User {
            var name: String
            var bio: String?

            func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                try encoder.encodeStructFields(count: nil) { structEncoder throws(CodingError.Encoding) in
                    try structEncoder.encode(key: "name", value: self.name)
                    if let value = self.bio {
                        try structEncoder.encode(key: "bio", value: value)
                    }
                }
            }
        }

        extension User: JSONEncodable {
        }
        """,
      macros: testMacros
    )
  }

  @Test func customKeys() {
    assertMacroExpansion(
      """
      @JSONEncodable
      struct User {
          @JSONKey("user_name") var userName: String
      }
      """,
      expandedSource: """
        struct User {
            var userName: String

            func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                try encoder.encodeStructFields(count: nil) { structEncoder throws(CodingError.Encoding) in
                    try structEncoder.encode(key: "user_name", value: self.userName)
                }
            }
        }

        extension User: JSONEncodable {
        }
        """,
      macros: testMacros
    )
  }

  @Test func bothMacros() {
    let bothMacros: [String: Macro.Type] = [
      "JSONDecodable": JSONDecodableMacro.self,
      "JSONEncodable": JSONEncodableMacro.self,
    ]

    assertMacroExpansion(
      """
      @JSONDecodable
      @JSONEncodable
      struct User {
          var name: String
          var age: Int
      }
      """,
      expandedSource: """
        struct User {
            var name: String
            var age: Int

            static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
                try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var name: String?
                    var age: Int?
                    try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                        switch key {
                        case "name": name = try valueDecoder.decode(String.self)
                        case "age": age = try valueDecoder.decode(Int.self)
                        default: break
                        }
                        return false
                    }
                    return User(
                        name: try name.unwrap(key: "name"),
                        age: try age.unwrap(key: "age")
                    )
                }
            }

            func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                try encoder.encodeStructFields(count: nil) { structEncoder throws(CodingError.Encoding) in
                    try structEncoder.encode(key: "name", value: self.name)
                    try structEncoder.encode(key: "age", value: self.age)
                }
            }
        }

        extension User: JSONDecodable {
        }

        extension User: JSONEncodable {
        }
        """,
      macros: bothMacros
    )
  }

  @Test func codableMacro() {
    let codableMacros: [String: Macro.Type] = [
      "JSONCodable": JSONCodableMacro.self
    ]

    assertMacroExpansion(
      """
      @JSONCodable
      struct User {
          var name: String
          var age: Int
      }
      """,
      expandedSource: """
        struct User {
            var name: String
            var age: Int

            static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
                try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var name: String?
                    var age: Int?
                    try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                        switch key {
                        case "name": name = try valueDecoder.decode(String.self)
                        case "age": age = try valueDecoder.decode(Int.self)
                        default: break
                        }
                        return false
                    }
                    return User(
                        name: try name.unwrap(key: "name"),
                        age: try age.unwrap(key: "age")
                    )
                }
            }

            func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                try encoder.encodeStructFields(count: nil) { structEncoder throws(CodingError.Encoding) in
                    try structEncoder.encode(key: "name", value: self.name)
                    try structEncoder.encode(key: "age", value: self.age)
                }
            }
        }

        extension User: JSONDecodable {
        }

        extension User: JSONEncodable {
        }
        """,
      macros: codableMacros
    )
  }

  @Test func unknownFields() {
    assertMacroExpansion(
      """
      @JSONEncodable
      struct Market {
          var name: String
          @JSONUnknownFields var unknownFields: [(key: String, value: JSONPrimitive)]
      }
      """,
      expandedSource: """
        struct Market {
            var name: String
            var unknownFields: [(key: String, value: JSONPrimitive)]

            func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                try encoder.encodeStructFields(count: nil) { structEncoder throws(CodingError.Encoding) in
                    try structEncoder.encode(key: "name", value: self.name)
                    for (key, value) in self.unknownFields {
                        try structEncoder.encode(key: key, value: value)
                    }
                }
            }
        }

        extension Market: JSONEncodable {
        }
        """,
      macros: testMacros
    )
  }
}
