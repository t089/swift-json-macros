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

            func encode(to json: inout JSON) {
                json(Any.self) { encoder in
                    encoder["name"] = self.name
                    encoder["price"] = self.price
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

            func encode(to json: inout JSON) {
                json(Any.self) { encoder in
                    encoder["name"] = self.name
                    encoder["bio"] = self.bio
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

            func encode(to json: inout JSON) {
                json(Any.self) { encoder in
                    encoder["user_name"] = self.userName
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

            init(json: borrowing JSON.Node) throws {
                let object: JSON.Object = try .init(json: json)
                var name: String?
                var age: Int?
                for field: JSON.FieldDecoder<String> in copy object {
                    switch field.key {
                    case "name": name = try field.decode()
                    case "age": age = try field.decode()
                    default: break
                    }
                }
                self.name = try name.unwrap(key: "name")
                self.age = try age.unwrap(key: "age")
            }

            func encode(to json: inout JSON) {
                json(Any.self) { encoder in
                    encoder["name"] = self.name
                    encoder["age"] = self.age
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

  @Test func unknownFields() {
    assertMacroExpansion(
      """
      @JSONEncodable
      struct Market {
          var name: String
          @JSONUnknownFields var unknownFields: JSON.Object
      }
      """,
      expandedSource: """
        struct Market {
            var name: String
            var unknownFields: JSON.Object

            func encode(to json: inout JSON) {
                json(Any.self) { encoder in
                    encoder["name"] = self.name
                    for field: JSON.FieldDecoder<String> in self.unknownFields {
                        encoder[field.key] = field.value
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
