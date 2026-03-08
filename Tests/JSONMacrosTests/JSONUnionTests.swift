import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

@testable import JSONMacrosPlugin

private let testMacros: [String: Macro.Type] = [
  "JSONUnion": JSONUnionMacro.self,
  "JSONCase": JSONCaseMacro.self,
  "JSONDefaultCase": JSONDefaultCaseMacro.self,
]

@Suite("JSONUnion macro")
struct JSONUnionTests {
  @Test func basicUnion() {
    assertMacroExpansion(
      """
      @JSONUnion("type")
      enum Shape {
          case circle(Circle)
          case rectangle(Rectangle)
      }
      """,
      expandedSource: """
        enum Shape {
            case circle(Circle)
            case rectangle(Rectangle)

            static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
                try decoder.decodeStruct { s throws(CodingError.Decoding) in
                    var type: String?
                    var fields: [(key: String, value: JSONPrimitive)] = []
                    try s.decodeEachKeyAndValue { (key, valueDecoder: inout _) throws(CodingError.Decoding) -> Void in
                        if key == "type" {
                            type = try valueDecoder.decode(String.self)
                            fields.append((key: key, value: .string(type!)))
                        } else {
                            fields.append((key: key, value: try valueDecoder.decodeJSONPrimitive()))
                        }
                    }
                    let primitive = JSONPrimitive.dictionary(fields)
                    switch type {
                    case "circle":
                        var d = JSONPrimitiveDecoder(value: primitive)
                        return .circle(try d.decode(Circle.self))
                    case "rectangle":
                        var d = JSONPrimitiveDecoder(value: primitive)
                        return .rectangle(try d.decode(Rectangle.self))
                    default:
                        throw CodingError.dataCorrupted(debugDescription: "Unknown \\"type\\" value: \\(type ?? \\"nil\\")")
                    }
                }
            }

            func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                switch self {
                case .circle(let content): try content.encode(to: &encoder)
                case .rectangle(let content): try content.encode(to: &encoder)
                }
            }
        }

        extension Shape: JSONDecodable, JSONEncodable {
        }
        """,
      macros: testMacros
    )
  }

  @Test func camelCaseToSnakeCase() {
    assertMacroExpansion(
      """
      @JSONUnion("type")
      enum Event {
          case toolUse(ToolUse)
          case webSearchResult(WebSearchResult)
      }
      """,
      expandedSource: """
        enum Event {
            case toolUse(ToolUse)
            case webSearchResult(WebSearchResult)

            static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
                try decoder.decodeStruct { s throws(CodingError.Decoding) in
                    var type: String?
                    var fields: [(key: String, value: JSONPrimitive)] = []
                    try s.decodeEachKeyAndValue { (key, valueDecoder: inout _) throws(CodingError.Decoding) -> Void in
                        if key == "type" {
                            type = try valueDecoder.decode(String.self)
                            fields.append((key: key, value: .string(type!)))
                        } else {
                            fields.append((key: key, value: try valueDecoder.decodeJSONPrimitive()))
                        }
                    }
                    let primitive = JSONPrimitive.dictionary(fields)
                    switch type {
                    case "tool_use":
                        var d = JSONPrimitiveDecoder(value: primitive)
                        return .toolUse(try d.decode(ToolUse.self))
                    case "web_search_result":
                        var d = JSONPrimitiveDecoder(value: primitive)
                        return .webSearchResult(try d.decode(WebSearchResult.self))
                    default:
                        throw CodingError.dataCorrupted(debugDescription: "Unknown \\"type\\" value: \\(type ?? \\"nil\\")")
                    }
                }
            }

            func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                switch self {
                case .toolUse(let content): try content.encode(to: &encoder)
                case .webSearchResult(let content): try content.encode(to: &encoder)
                }
            }
        }

        extension Event: JSONDecodable, JSONEncodable {
        }
        """,
      macros: testMacros
    )
  }

  @Test func customCaseNames() {
    assertMacroExpansion(
      """
      @JSONUnion("type")
      enum Block {
          case text(Text)
          @JSONCase("custom_block")
          case custom(Custom)
      }
      """,
      expandedSource: """
        enum Block {
            case text(Text)
            case custom(Custom)

            static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
                try decoder.decodeStruct { s throws(CodingError.Decoding) in
                    var type: String?
                    var fields: [(key: String, value: JSONPrimitive)] = []
                    try s.decodeEachKeyAndValue { (key, valueDecoder: inout _) throws(CodingError.Decoding) -> Void in
                        if key == "type" {
                            type = try valueDecoder.decode(String.self)
                            fields.append((key: key, value: .string(type!)))
                        } else {
                            fields.append((key: key, value: try valueDecoder.decodeJSONPrimitive()))
                        }
                    }
                    let primitive = JSONPrimitive.dictionary(fields)
                    switch type {
                    case "text":
                        var d = JSONPrimitiveDecoder(value: primitive)
                        return .text(try d.decode(Text.self))
                    case "custom_block":
                        var d = JSONPrimitiveDecoder(value: primitive)
                        return .custom(try d.decode(Custom.self))
                    default:
                        throw CodingError.dataCorrupted(debugDescription: "Unknown \\"type\\" value: \\(type ?? \\"nil\\")")
                    }
                }
            }

            func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                switch self {
                case .text(let content): try content.encode(to: &encoder)
                case .custom(let content): try content.encode(to: &encoder)
                }
            }
        }

        extension Block: JSONDecodable, JSONEncodable {
        }
        """,
      macros: testMacros
    )
  }

  @Test func multipleCaseNames() {
    assertMacroExpansion(
      """
      @JSONUnion("type")
      enum Block {
          case text(Text)
          @JSONCase("beta_a", "beta_b")
          case beta(Beta)
      }
      """,
      expandedSource: """
        enum Block {
            case text(Text)
            case beta(Beta)

            static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
                try decoder.decodeStruct { s throws(CodingError.Decoding) in
                    var type: String?
                    var fields: [(key: String, value: JSONPrimitive)] = []
                    try s.decodeEachKeyAndValue { (key, valueDecoder: inout _) throws(CodingError.Decoding) -> Void in
                        if key == "type" {
                            type = try valueDecoder.decode(String.self)
                            fields.append((key: key, value: .string(type!)))
                        } else {
                            fields.append((key: key, value: try valueDecoder.decodeJSONPrimitive()))
                        }
                    }
                    let primitive = JSONPrimitive.dictionary(fields)
                    switch type {
                    case "text":
                        var d = JSONPrimitiveDecoder(value: primitive)
                        return .text(try d.decode(Text.self))
                    case "beta_a", "beta_b":
                        var d = JSONPrimitiveDecoder(value: primitive)
                        return .beta(try d.decode(Beta.self))
                    default:
                        throw CodingError.dataCorrupted(debugDescription: "Unknown \\"type\\" value: \\(type ?? \\"nil\\")")
                    }
                }
            }

            func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                switch self {
                case .text(let content): try content.encode(to: &encoder)
                case .beta(let content): try content.encode(to: &encoder)
                }
            }
        }

        extension Block: JSONDecodable, JSONEncodable {
        }
        """,
      macros: testMacros
    )
  }

  @Test func defaultCase() {
    assertMacroExpansion(
      """
      @JSONUnion("type")
      enum Block {
          case text(Text)
          case image(Image)
          @JSONDefaultCase
          case unknown(StructuredData)
      }
      """,
      expandedSource: """
        enum Block {
            case text(Text)
            case image(Image)
            case unknown(StructuredData)

            static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
                try decoder.decodeStruct { s throws(CodingError.Decoding) in
                    var type: String?
                    var fields: [(key: String, value: JSONPrimitive)] = []
                    try s.decodeEachKeyAndValue { (key, valueDecoder: inout _) throws(CodingError.Decoding) -> Void in
                        if key == "type" {
                            type = try valueDecoder.decode(String.self)
                            fields.append((key: key, value: .string(type!)))
                        } else {
                            fields.append((key: key, value: try valueDecoder.decodeJSONPrimitive()))
                        }
                    }
                    let primitive = JSONPrimitive.dictionary(fields)
                    switch type {
                    case "text":
                        var d = JSONPrimitiveDecoder(value: primitive)
                        return .text(try d.decode(Text.self))
                    case "image":
                        var d = JSONPrimitiveDecoder(value: primitive)
                        return .image(try d.decode(Image.self))
                    default:
                        var d = JSONPrimitiveDecoder(value: primitive)
                        return .unknown(try d.decode(StructuredData.self))
                    }
                }
            }

            func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                switch self {
                case .text(let content): try content.encode(to: &encoder)
                case .image(let content): try content.encode(to: &encoder)
                case .unknown(let content): try content.encode(to: &encoder)
                }
            }
        }

        extension Block: JSONDecodable, JSONEncodable {
        }
        """,
      macros: testMacros
    )
  }

  @Test func appliedToStruct() {
    assertMacroExpansion(
      """
      @JSONUnion("type")
      struct Foo {
          var x: Int
      }
      """,
      expandedSource: """
        struct Foo {
            var x: Int
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "@JSONUnion can only be applied to enums",
          line: 1,
          column: 1
        )
      ],
      macros: testMacros
    )
  }

  @Test func camelCaseNaming() {
    assertMacroExpansion(
      """
      @JSONUnion("type", naming: .camelCase)
      enum Event {
          case toolUse(ToolUse)
          case webSearch(WebSearch)
      }
      """,
      expandedSource: """
        enum Event {
            case toolUse(ToolUse)
            case webSearch(WebSearch)

            static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
                try decoder.decodeStruct { s throws(CodingError.Decoding) in
                    var type: String?
                    var fields: [(key: String, value: JSONPrimitive)] = []
                    try s.decodeEachKeyAndValue { (key, valueDecoder: inout _) throws(CodingError.Decoding) -> Void in
                        if key == "type" {
                            type = try valueDecoder.decode(String.self)
                            fields.append((key: key, value: .string(type!)))
                        } else {
                            fields.append((key: key, value: try valueDecoder.decodeJSONPrimitive()))
                        }
                    }
                    let primitive = JSONPrimitive.dictionary(fields)
                    switch type {
                    case "toolUse":
                        var d = JSONPrimitiveDecoder(value: primitive)
                        return .toolUse(try d.decode(ToolUse.self))
                    case "webSearch":
                        var d = JSONPrimitiveDecoder(value: primitive)
                        return .webSearch(try d.decode(WebSearch.self))
                    default:
                        throw CodingError.dataCorrupted(debugDescription: "Unknown \\"type\\" value: \\(type ?? \\"nil\\")")
                    }
                }
            }

            func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                switch self {
                case .toolUse(let content): try content.encode(to: &encoder)
                case .webSearch(let content): try content.encode(to: &encoder)
                }
            }
        }

        extension Event: JSONDecodable, JSONEncodable {
        }
        """,
      macros: testMacros
    )
  }

  @Test func upperSnakeCaseNaming() {
    assertMacroExpansion(
      """
      @JSONUnion("type", naming: .upperSnakeCase)
      enum Status {
          case inProgress(InProgress)
          case completed(Completed)
      }
      """,
      expandedSource: """
        enum Status {
            case inProgress(InProgress)
            case completed(Completed)

            static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
                try decoder.decodeStruct { s throws(CodingError.Decoding) in
                    var type: String?
                    var fields: [(key: String, value: JSONPrimitive)] = []
                    try s.decodeEachKeyAndValue { (key, valueDecoder: inout _) throws(CodingError.Decoding) -> Void in
                        if key == "type" {
                            type = try valueDecoder.decode(String.self)
                            fields.append((key: key, value: .string(type!)))
                        } else {
                            fields.append((key: key, value: try valueDecoder.decodeJSONPrimitive()))
                        }
                    }
                    let primitive = JSONPrimitive.dictionary(fields)
                    switch type {
                    case "IN_PROGRESS":
                        var d = JSONPrimitiveDecoder(value: primitive)
                        return .inProgress(try d.decode(InProgress.self))
                    case "COMPLETED":
                        var d = JSONPrimitiveDecoder(value: primitive)
                        return .completed(try d.decode(Completed.self))
                    default:
                        throw CodingError.dataCorrupted(debugDescription: "Unknown \\"type\\" value: \\(type ?? \\"nil\\")")
                    }
                }
            }

            func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                switch self {
                case .inProgress(let content): try content.encode(to: &encoder)
                case .completed(let content): try content.encode(to: &encoder)
                }
            }
        }

        extension Status: JSONDecodable, JSONEncodable {
        }
        """,
      macros: testMacros
    )
  }
}
