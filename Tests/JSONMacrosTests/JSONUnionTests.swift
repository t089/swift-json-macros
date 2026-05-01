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

            init(json: borrowing JSON.Node) throws {
                let object: JSON.Object = try .init(json: json)
                var discriminator: String? = nil
                for field: JSON.FieldDecoder<String> in copy object {
                    if field.key == "type" {
                        discriminator = try field.decode()
                        break
                    }
                }
                switch discriminator {
                case "circle": self = .circle(try .init(json: json))
                case "rectangle": self = .rectangle(try .init(json: json))
                case let other?: throw JSON.ValueError<String, Self>(invalid: other)
                case nil: throw JSON.ObjectKeyError<String>.undefined("type")
                }
            }

            func encode(to json: inout JSON) {
                switch self {
                case .circle(let content): content.encode(to: &json)
                case .rectangle(let content): content.encode(to: &json)
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

            init(json: borrowing JSON.Node) throws {
                let object: JSON.Object = try .init(json: json)
                var discriminator: String? = nil
                for field: JSON.FieldDecoder<String> in copy object {
                    if field.key == "type" {
                        discriminator = try field.decode()
                        break
                    }
                }
                switch discriminator {
                case "tool_use": self = .toolUse(try .init(json: json))
                case "web_search_result": self = .webSearchResult(try .init(json: json))
                case let other?: throw JSON.ValueError<String, Self>(invalid: other)
                case nil: throw JSON.ObjectKeyError<String>.undefined("type")
                }
            }

            func encode(to json: inout JSON) {
                switch self {
                case .toolUse(let content): content.encode(to: &json)
                case .webSearchResult(let content): content.encode(to: &json)
                }
            }
        }

        extension Event: JSONDecodable, JSONEncodable {
        }
        """,
      macros: testMacros
    )
  }

  @Test func customCaseNameAndDefault() {
    assertMacroExpansion(
      """
      @JSONUnion("type")
      enum Block {
          case text(TextBlock)
          @JSONCase("img")
          case image(ImageBlock)
          @JSONDefaultCase
          case unknown(JSON.Node)
      }
      """,
      expandedSource: """
        enum Block {
            case text(TextBlock)
            case image(ImageBlock)
            case unknown(JSON.Node)

            init(json: borrowing JSON.Node) throws {
                let object: JSON.Object = try .init(json: json)
                var discriminator: String? = nil
                for field: JSON.FieldDecoder<String> in copy object {
                    if field.key == "type" {
                        discriminator = try field.decode()
                        break
                    }
                }
                switch discriminator {
                case "text": self = .text(try .init(json: json))
                case "img": self = .image(try .init(json: json))
                default: self = .unknown(try .init(json: json))
                }
            }

            func encode(to json: inout JSON) {
                switch self {
                case .text(let content): content.encode(to: &json)
                case .image(let content): content.encode(to: &json)
                case .unknown(let content): content.encode(to: &json)
                }
            }
        }

        extension Block: JSONDecodable, JSONEncodable {
        }
        """,
      macros: testMacros
    )
  }

  @Test func payloadlessCase() {
    assertMacroExpansion(
      """
      @JSONUnion("type")
      enum Event {
          case ping
          case message(Message)
      }
      """,
      expandedSource: """
        enum Event {
            case ping
            case message(Message)

            init(json: borrowing JSON.Node) throws {
                let object: JSON.Object = try .init(json: json)
                var discriminator: String? = nil
                for field: JSON.FieldDecoder<String> in copy object {
                    if field.key == "type" {
                        discriminator = try field.decode()
                        break
                    }
                }
                switch discriminator {
                case "ping": self = .ping
                case "message": self = .message(try .init(json: json))
                case let other?: throw JSON.ValueError<String, Self>(invalid: other)
                case nil: throw JSON.ObjectKeyError<String>.undefined("type")
                }
            }

            func encode(to json: inout JSON) {
                switch self {
                case .ping:
                        json(Any.self) { encoder in
                            encoder["type"] = "ping"
                        }
                case .message(let content): content.encode(to: &json)
                }
            }
        }

        extension Event: JSONDecodable, JSONEncodable {
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
      }
      """,
      expandedSource: """
        struct Foo {
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
}
