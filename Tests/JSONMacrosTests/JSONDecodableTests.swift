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

            init(json: borrowing JSON.Node) throws {
                let object: JSON.Object = try .init(json: json)
                var name: String?
                var price: Double?
                var isActive: Bool?
                for field: JSON.FieldDecoder<String> in copy object {
                    switch field.key {
                    case "name": name = try field.decode()
                    case "price": price = try field.decode()
                    case "isActive": isActive = try field.decode()
                    default: break
                    }
                }
                self.name = try name.unwrap(key: "name")
                self.price = try price.unwrap(key: "price")
                self.isActive = try isActive.unwrap(key: "isActive")
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

            init(json: borrowing JSON.Node) throws {
                let object: JSON.Object = try .init(json: json)
                var name: String?
                var bio: String? = nil
                var age: Optional<Int> = nil
                for field: JSON.FieldDecoder<String> in copy object {
                    switch field.key {
                    case "name": name = try field.decode()
                    case "bio": bio = try field.decode()
                    case "age": age = try field.decode()
                    default: break
                    }
                }
                self.name = try name.unwrap(key: "name")
                self.bio = bio
                self.age = age
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

            init(json: borrowing JSON.Node) throws {
                let object: JSON.Object = try .init(json: json)
                var userName: String?
                var isActive: Bool?
                for field: JSON.FieldDecoder<String> in copy object {
                    switch field.key {
                    case "user_name": userName = try field.decode()
                    case "is_active": isActive = try field.decode()
                    default: break
                    }
                }
                self.userName = try userName.unwrap(key: "user_name")
                self.isActive = try isActive.unwrap(key: "is_active")
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

            init(json: borrowing JSON.Node) throws {
                let object: JSON.Object = try .init(json: json)
                var name: String?
                for field: JSON.FieldDecoder<String> in copy object {
                    switch field.key {
                    case "name": name = try field.decode()
                    default: break
                    }
                }
                self.name = try name.unwrap(key: "name")
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
          @JSONUnknownFields var unknownFields: JSON.Object
      }
      """,
      expandedSource: """
        struct Market {
            var name: String
            var unknownFields: JSON.Object

            init(json: borrowing JSON.Node) throws {
                let object: JSON.Object = try .init(json: json)
                var name: String?
                var unknownFields: [(key: JSON.Key, value: JSON.Node)] = []
                for field: JSON.FieldDecoder<String> in copy object {
                    switch field.key {
                    case "name": name = try field.decode()
                    default: unknownFields.append((key: .init(rawValue: field.key), value: field.value))
                    }
                }
                self.name = try name.unwrap(key: "name")
                self.unknownFields = .init(unknownFields)
            }
        }

        extension Market: JSONDecodable {
        }
        """,
      macros: testMacros
    )
  }
}
