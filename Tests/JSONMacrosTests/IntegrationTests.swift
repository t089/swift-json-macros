import JSONMacros
import Testing

#if canImport(FoundationEssentials)
  import FoundationEssentials
#else
  import Foundation
#endif

// MARK: - Test types

@JSONCodable
struct Address {
  var street: String
  var city: String
  var zip: Int
}

@JSONCodable
struct BasicTypes {
  var name: String
  var age: Int
  var score: Double
  var isActive: Bool
}

@JSONCodable
struct WithOptionals {
  var name: String
  var bio: String?
  var age: Optional<Int>
}

@JSONCodable
struct WithArrays {
  var tags: [String]
  var scores: [Int]
  var nested: [[Double]]
}

@JSONCodable
struct WithNested {
  var name: String
  var address: Address
}

@JSONCodable
struct WithCustomKeys {
  @JSONKey("user_name") var userName: String
  @JSONKey("is_active") var isActive: Bool
  @JSONKey("created_at") var createdAt: String
}

@JSONCodable
struct WithUnknownFields {
  var name: String
  var age: Int
  @JSONUnknownFields var unknownFields: [(key: String, value: JSONPrimitive)]
}

@JSONCodable
struct Complex {
  var title: String
  var tags: [String]
  var address: Address?
  @JSONKey("is_published") var isPublished: Bool
}

@JSONCodable(naming: .snakeCase)
struct SnakeCaseUser {
  var userName: String
  var isActive: Bool
  var createdAt: String
}

@JSONCodable
struct WithIgnored {
  var name: String
  @JSONIgnore var cached: String = "default"
}

// Helper to decode JSON from a string
private func decode<T: JSONDecodable>(_ type: T.Type, from string: String) throws -> T {
  let decoder = NewJSONDecoder()
  return try decoder.decode(type, from: Data(string.utf8))
}

private func encode<T: JSONEncodable>(_ value: borrowing T) throws -> Data {
  let encoder = NewJSONEncoder()
  return try encoder.encode(value)
}

// MARK: - Decoding Tests

@Suite("Integration: Decoding")
struct DecodingTests {
  @Test func basicTypes() throws {
    let value = try decode(
      BasicTypes.self,
      from: """
        {"name":"Alice","age":30,"score":9.5,"isActive":true}
        """)
    #expect(value.name == "Alice")
    #expect(value.age == 30)
    #expect(value.score == 9.5)
    #expect(value.isActive == true)
  }

  @Test func optionalPresent() throws {
    let value = try decode(
      WithOptionals.self,
      from: """
        {"name":"Bob","bio":"Hello world","age":25}
        """)
    #expect(value.name == "Bob")
    #expect(value.bio == "Hello world")
    #expect(value.age == 25)
  }

  @Test func optionalMissing() throws {
    let value = try decode(
      WithOptionals.self,
      from: """
        {"name":"Charlie"}
        """)
    #expect(value.name == "Charlie")
    #expect(value.bio == nil)
    #expect(value.age == nil)
  }

  @Test func arrays() throws {
    let value = try decode(
      WithArrays.self,
      from: """
        {"tags":["swift","json"],"scores":[1,2,3],"nested":[[1.0,2.0],[3.0]]}
        """)
    #expect(value.tags == ["swift", "json"])
    #expect(value.scores == [1, 2, 3])
    #expect(value.nested == [[1.0, 2.0], [3.0]])
  }

  @Test func emptyArrays() throws {
    let value = try decode(
      WithArrays.self,
      from: """
        {"tags":[],"scores":[],"nested":[]}
        """)
    #expect(value.tags == [])
    #expect(value.scores == [])
    #expect(value.nested == [])
  }

  @Test func nestedStruct() throws {
    let value = try decode(
      WithNested.self,
      from: """
        {"name":"Alice","address":{"street":"123 Main St","city":"Berlin","zip":10115}}
        """)
    #expect(value.name == "Alice")
    #expect(value.address.street == "123 Main St")
    #expect(value.address.city == "Berlin")
    #expect(value.address.zip == 10115)
  }

  @Test func customKeys() throws {
    let value = try decode(
      WithCustomKeys.self,
      from: """
        {"user_name":"alice","is_active":true,"created_at":"2025-01-01"}
        """)
    #expect(value.userName == "alice")
    #expect(value.isActive == true)
    #expect(value.createdAt == "2025-01-01")
  }

  @Test func snakeCaseNaming() throws {
    let value = try decode(
      SnakeCaseUser.self,
      from: """
        {"user_name":"alice","is_active":true,"created_at":"2025-01-01"}
        """)
    #expect(value.userName == "alice")
    #expect(value.isActive == true)
    #expect(value.createdAt == "2025-01-01")

    // Round-trip
    let data = try encode(value)
    let jsonString = String(decoding: data, as: UTF8.self)
    #expect(jsonString.contains("\"user_name\""))
    #expect(jsonString.contains("\"is_active\""))
    #expect(jsonString.contains("\"created_at\""))
  }

  @Test func unknownFieldsPreserved() throws {
    let value = try decode(
      WithUnknownFields.self,
      from: """
        {"name":"Alice","age":30,"email":"alice@example.com","role":"admin"}
        """)
    #expect(value.name == "Alice")
    #expect(value.age == 30)
    #expect(value.unknownFields.count == 2)
    #expect(value.unknownFields[0].key == "email")
    #expect(value.unknownFields[0].value == .string("alice@example.com"))
    #expect(value.unknownFields[1].key == "role")
    #expect(value.unknownFields[1].value == .string("admin"))
  }

  @Test func missingRequiredFieldThrows() throws {
    #expect(throws: (any Error).self) {
      try decode(
        BasicTypes.self,
        from: """
          {"name":"Alice"}
          """)
    }
  }

  @Test func extraFieldsIgnored() throws {
    let value = try decode(
      BasicTypes.self,
      from: """
        {"name":"Alice","age":30,"score":9.5,"isActive":true,"extra":"ignored"}
        """)
    #expect(value.name == "Alice")
  }

  @Test func complex() throws {
    let value = try decode(
      Complex.self,
      from: """
        {"title":"Post","tags":["a","b"],"address":{"street":"X","city":"Y","zip":1},"is_published":true}
        """)
    #expect(value.title == "Post")
    #expect(value.tags == ["a", "b"])
    #expect(value.address?.street == "X")
    #expect(value.isPublished == true)
  }

  @Test func ignoredFieldNotDecoded() throws {
    let value = try decode(
      WithIgnored.self,
      from: """
        {"name":"Alice","cached":"should be ignored"}
        """)
    #expect(value.name == "Alice")
    #expect(value.cached == "default")
  }

  @Test func complexOptionalNil() throws {
    let value = try decode(
      Complex.self,
      from: """
        {"title":"Post","tags":[],"is_published":false}
        """)
    #expect(value.title == "Post")
    #expect(value.tags == [])
    #expect(value.address == nil)
    #expect(value.isPublished == false)
  }
}

// MARK: - Encoding Tests

@Suite("Integration: Encoding")
struct EncodingTests {
  @Test func basicTypes() throws {
    let value = try decode(
      BasicTypes.self,
      from: """
        {"name":"Alice","age":30,"score":9.5,"isActive":true}
        """)
    let data = try encode(value)
    let decoded = try NewJSONDecoder().decode(BasicTypes.self, from: data)
    #expect(decoded.name == "Alice")
    #expect(decoded.age == 30)
    #expect(decoded.score == 9.5)
    #expect(decoded.isActive == true)
  }

  @Test func optionalPresent() throws {
    let value = try decode(
      WithOptionals.self,
      from: """
        {"name":"Bob","bio":"Hello","age":25}
        """)
    let data = try encode(value)
    let decoded = try NewJSONDecoder().decode(WithOptionals.self, from: data)
    #expect(decoded.name == "Bob")
    #expect(decoded.bio == "Hello")
    #expect(decoded.age == 25)
  }

  @Test func optionalNil() throws {
    let value = try decode(
      WithOptionals.self,
      from: """
        {"name":"Charlie"}
        """)
    let data = try encode(value)
    let decoded = try NewJSONDecoder().decode(WithOptionals.self, from: data)
    #expect(decoded.name == "Charlie")
    #expect(decoded.bio == nil)
    #expect(decoded.age == nil)
  }

  @Test func arrays() throws {
    let value = try decode(
      WithArrays.self,
      from: """
        {"tags":["a","b"],"scores":[1,2,3],"nested":[[1.0],[2.0,3.0]]}
        """)
    let data = try encode(value)
    let decoded = try NewJSONDecoder().decode(WithArrays.self, from: data)
    #expect(decoded.tags == ["a", "b"])
    #expect(decoded.scores == [1, 2, 3])
    #expect(decoded.nested == [[1.0], [2.0, 3.0]])
  }

  @Test func nestedStruct() throws {
    let value = try decode(
      WithNested.self,
      from: """
        {"name":"Alice","address":{"street":"Main St","city":"Berlin","zip":10115}}
        """)
    let data = try encode(value)
    let decoded = try NewJSONDecoder().decode(WithNested.self, from: data)
    #expect(decoded.name == "Alice")
    #expect(decoded.address.street == "Main St")
    #expect(decoded.address.city == "Berlin")
    #expect(decoded.address.zip == 10115)
  }

  @Test func customKeys() throws {
    let value = try decode(
      WithCustomKeys.self,
      from: """
        {"user_name":"alice","is_active":true,"created_at":"2025-01-01"}
        """)
    let data = try encode(value)
    let jsonString = String(decoding: data, as: UTF8.self)
    #expect(jsonString.contains("\"user_name\""))
    #expect(jsonString.contains("\"is_active\""))
    #expect(jsonString.contains("\"created_at\""))
    let decoded = try NewJSONDecoder().decode(WithCustomKeys.self, from: data)
    #expect(decoded.userName == "alice")
    #expect(decoded.isActive == true)
    #expect(decoded.createdAt == "2025-01-01")
  }

  @Test func complex() throws {
    let value = try decode(
      Complex.self,
      from: """
        {"title":"Post","tags":["swift","json"],"address":{"street":"X","city":"Y","zip":1},"is_published":true}
        """)
    let data = try encode(value)
    let decoded = try NewJSONDecoder().decode(Complex.self, from: data)
    #expect(decoded.title == "Post")
    #expect(decoded.tags == ["swift", "json"])
    #expect(decoded.address?.street == "X")
    #expect(decoded.isPublished == true)
  }

  @Test func ignoredFieldNotEncoded() throws {
    var value = WithIgnored(name: "Alice")
    value.cached = "something"
    let data = try encode(value)
    let jsonString = String(decoding: data, as: UTF8.self)
    #expect(jsonString.contains("\"name\""))
    #expect(!jsonString.contains("cached"))
  }
}

// MARK: - Round-trip Tests

@Suite("Integration: Round-trip")
struct RoundTripTests {
  @Test func basicRoundTrip() throws {
    let original = try decode(
      BasicTypes.self,
      from: """
        {"name":"Test","age":42,"score":3.14,"isActive":false}
        """)
    let data = try encode(original)
    let decoded = try NewJSONDecoder().decode(BasicTypes.self, from: data)
    #expect(decoded.name == original.name)
    #expect(decoded.age == original.age)
    #expect(decoded.score == original.score)
    #expect(decoded.isActive == original.isActive)
  }

  @Test func nestedRoundTrip() throws {
    let original = try decode(
      WithNested.self,
      from: """
        {"name":"Test","address":{"street":"Elm St","city":"Munich","zip":80331}}
        """)
    let data = try encode(original)
    let decoded = try NewJSONDecoder().decode(WithNested.self, from: data)
    #expect(decoded.name == original.name)
    #expect(decoded.address.street == original.address.street)
    #expect(decoded.address.city == original.address.city)
    #expect(decoded.address.zip == original.address.zip)
  }

  @Test func unknownFieldsRoundTrip() throws {
    let original = try decode(
      WithUnknownFields.self,
      from: """
        {"name":"Alice","age":30,"email":"alice@example.com","score":9.5,"active":true}
        """)
    #expect(original.name == "Alice")
    #expect(original.age == 30)

    let data = try encode(original)
    let reDecoded = try NewJSONDecoder().decode(WithUnknownFields.self, from: data)
    #expect(reDecoded.name == "Alice")
    #expect(reDecoded.age == 30)
    #expect(reDecoded.unknownFields.count == 3)
  }

  @Test func complexRoundTrip() throws {
    let original = try decode(
      Complex.self,
      from: """
        {"title":"Hello","tags":["x","y","z"],"is_published":false}
        """)
    let data = try encode(original)
    let decoded = try NewJSONDecoder().decode(Complex.self, from: data)
    #expect(decoded.title == original.title)
    #expect(decoded.tags == original.tags)
    #expect(decoded.address == nil)
    #expect(decoded.isPublished == original.isPublished)
  }
}
