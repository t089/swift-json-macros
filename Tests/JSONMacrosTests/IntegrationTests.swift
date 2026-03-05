import JSONMacros
import Testing

// MARK: - Test types

enum MarketType: String, JSONDecodable, JSONEncodable {
  case spot
  case future
  case perpetual
}

enum Priority: Int, JSONDecodable, JSONEncodable {
  case low = 0
  case medium = 1
  case high = 2
}

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
struct WithEnum {
  var name: String
  var type: MarketType
  var priority: Priority
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
  @JSONUnknownFields var unknownFields: JSON.Object
}

@JSONCodable
struct WithArbitraryJSON {
  var name: String
  var metadata: JSON.Node
}

@JSONCodable
struct WithArbitraryObject {
  var name: String
  var config: JSON.Object
}

@JSONCodable
struct Complex {
  var title: String
  var tags: [String]
  var type: MarketType
  var address: Address?
  @JSONKey("is_published") var isPublished: Bool
}

// Helper to parse JSON from a string
private func json(_ string: String) -> JSON {
  JSON(utf8: ArraySlice(string.utf8))
}

// MARK: - Decoding Tests

@Suite("Integration: Decoding")
struct DecodingTests {
  @Test func basicTypes() throws {
    let value: BasicTypes = try json(
      """
      {"name":"Alice","age":30,"score":9.5,"isActive":true}
      """
    ).decode()
    #expect(value.name == "Alice")
    #expect(value.age == 30)
    #expect(value.score == 9.5)
    #expect(value.isActive == true)
  }

  @Test func optionalPresent() throws {
    let value: WithOptionals = try json(
      """
      {"name":"Bob","bio":"Hello world","age":25}
      """
    ).decode()
    #expect(value.name == "Bob")
    #expect(value.bio == "Hello world")
    #expect(value.age == 25)
  }

  @Test func optionalMissing() throws {
    let value: WithOptionals = try json(
      """
      {"name":"Charlie"}
      """
    ).decode()
    #expect(value.name == "Charlie")
    #expect(value.bio == nil)
    #expect(value.age == nil)
  }

  @Test func optionalExplicitNull() throws {
    let value: WithOptionals = try json(
      """
      {"name":"Dana","bio":null,"age":null}
      """
    ).decode()
    #expect(value.name == "Dana")
    #expect(value.bio == nil)
    #expect(value.age == nil)
  }

  @Test func arrays() throws {
    let value: WithArrays = try json(
      """
      {"tags":["swift","json"],"scores":[1,2,3],"nested":[[1.0,2.0],[3.0]]}
      """
    ).decode()
    #expect(value.tags == ["swift", "json"])
    #expect(value.scores == [1, 2, 3])
    #expect(value.nested == [[1.0, 2.0], [3.0]])
  }

  @Test func emptyArrays() throws {
    let value: WithArrays = try json(
      """
      {"tags":[],"scores":[],"nested":[]}
      """
    ).decode()
    #expect(value.tags == [])
    #expect(value.scores == [])
    #expect(value.nested == [])
  }

  @Test func stringEnum() throws {
    let value: WithEnum = try json(
      """
      {"name":"BTC-PERP","type":"perpetual","priority":2}
      """
    ).decode()
    #expect(value.name == "BTC-PERP")
    #expect(value.type == .perpetual)
    #expect(value.priority == .high)
  }

  @Test func nestedStruct() throws {
    let value: WithNested = try json(
      """
      {"name":"Alice","address":{"street":"123 Main St","city":"Berlin","zip":10115}}
      """
    ).decode()
    #expect(value.name == "Alice")
    #expect(value.address.street == "123 Main St")
    #expect(value.address.city == "Berlin")
    #expect(value.address.zip == 10115)
  }

  @Test func customKeys() throws {
    let value: WithCustomKeys = try json(
      """
      {"user_name":"alice","is_active":true,"created_at":"2025-01-01"}
      """
    ).decode()
    #expect(value.userName == "alice")
    #expect(value.isActive == true)
    #expect(value.createdAt == "2025-01-01")
  }

  @Test func unknownFieldsPreserved() throws {
    let value: WithUnknownFields = try json(
      """
      {"name":"Alice","age":30,"email":"alice@example.com","role":"admin"}
      """
    ).decode()
    #expect(value.name == "Alice")
    #expect(value.age == 30)
    #expect(value.unknownFields.fields.count == 2)
    #expect(value.unknownFields.fields[0].key.rawValue == "email")
    #expect(value.unknownFields.fields[1].key.rawValue == "role")
  }

  @Test func arbitraryJSONNode() throws {
    let value: WithArbitraryJSON = try json(
      """
      {"name":"Alice","metadata":{"x":1,"y":[true,"hello"]}}
      """
    ).decode()
    #expect(value.name == "Alice")
    guard case .object(let obj) = value.metadata else {
      Issue.record("Expected object node")
      return
    }
    #expect(obj.fields.count == 2)
  }

  @Test func arbitraryJSONObject() throws {
    let value: WithArbitraryObject = try json(
      """
      {"name":"Bob","config":{"debug":true,"level":5}}
      """
    ).decode()
    #expect(value.name == "Bob")
    #expect(value.config.fields.count == 2)
  }

  @Test func missingRequiredFieldThrows() throws {
    #expect(throws: (any Error).self) {
      let _: BasicTypes = try json(
        """
        {"name":"Alice"}
        """
      ).decode()
    }
  }

  @Test func extraFieldsIgnored() throws {
    let value: BasicTypes = try json(
      """
      {"name":"Alice","age":30,"score":9.5,"isActive":true,"extra":"ignored"}
      """
    ).decode()
    #expect(value.name == "Alice")
  }

  @Test func complex() throws {
    let value: Complex = try json(
      """
      {"title":"Post","tags":["a","b"],"type":"spot","address":{"street":"X","city":"Y","zip":1},"is_published":true}
      """
    ).decode()
    #expect(value.title == "Post")
    #expect(value.tags == ["a", "b"])
    #expect(value.type == .spot)
    #expect(value.address?.street == "X")
    #expect(value.isPublished == true)
  }

  @Test func complexOptionalNil() throws {
    let value: Complex = try json(
      """
      {"title":"Post","tags":[],"type":"future","is_published":false}
      """
    ).decode()
    #expect(value.title == "Post")
    #expect(value.tags == [])
    #expect(value.type == .future)
    #expect(value.address == nil)
    #expect(value.isPublished == false)
  }
}

// MARK: - Encoding Tests

@Suite("Integration: Encoding")
struct EncodingTests {
  @Test func basicTypes() throws {
    let value: BasicTypes = try json(
      """
      {"name":"Alice","age":30,"score":9.5,"isActive":true}
      """
    ).decode()
    let encoded = JSON.encode(value)
    let decoded: BasicTypes = try encoded.decode()
    #expect(decoded.name == "Alice")
    #expect(decoded.age == 30)
    #expect(decoded.score == 9.5)
    #expect(decoded.isActive == true)
  }

  @Test func optionalPresent() throws {
    let value: WithOptionals = try json(
      """
      {"name":"Bob","bio":"Hello","age":25}
      """
    ).decode()
    let encoded = JSON.encode(value)
    let decoded: WithOptionals = try encoded.decode()
    #expect(decoded.name == "Bob")
    #expect(decoded.bio == "Hello")
    #expect(decoded.age == 25)
  }

  @Test func optionalNil() throws {
    let value: WithOptionals = try json(
      """
      {"name":"Charlie"}
      """
    ).decode()
    let encoded = JSON.encode(value)
    let decoded: WithOptionals = try encoded.decode()
    #expect(decoded.name == "Charlie")
    #expect(decoded.bio == nil)
    #expect(decoded.age == nil)
  }

  @Test func arrays() throws {
    let value: WithArrays = try json(
      """
      {"tags":["a","b"],"scores":[1,2,3],"nested":[[1.0],[2.0,3.0]]}
      """
    ).decode()
    let encoded = JSON.encode(value)
    let decoded: WithArrays = try encoded.decode()
    #expect(decoded.tags == ["a", "b"])
    #expect(decoded.scores == [1, 2, 3])
    #expect(decoded.nested == [[1.0], [2.0, 3.0]])
  }

  @Test func enums() throws {
    let value: WithEnum = try json(
      """
      {"name":"BTC","type":"future","priority":1}
      """
    ).decode()
    let encoded = JSON.encode(value)
    let decoded: WithEnum = try encoded.decode()
    #expect(decoded.name == "BTC")
    #expect(decoded.type == .future)
    #expect(decoded.priority == .medium)
  }

  @Test func nestedStruct() throws {
    let value: WithNested = try json(
      """
      {"name":"Alice","address":{"street":"Main St","city":"Berlin","zip":10115}}
      """
    ).decode()
    let encoded = JSON.encode(value)
    let decoded: WithNested = try encoded.decode()
    #expect(decoded.name == "Alice")
    #expect(decoded.address.street == "Main St")
    #expect(decoded.address.city == "Berlin")
    #expect(decoded.address.zip == 10115)
  }

  @Test func customKeys() throws {
    let value: WithCustomKeys = try json(
      """
      {"user_name":"alice","is_active":true,"created_at":"2025-01-01"}
      """
    ).decode()
    let encoded = JSON.encode(value)
    // Verify the JSON uses snake_case keys
    let jsonString = String(decoding: encoded.utf8, as: UTF8.self)
    #expect(jsonString.contains("\"user_name\""))
    #expect(jsonString.contains("\"is_active\""))
    #expect(jsonString.contains("\"created_at\""))
    // Round-trip
    let decoded: WithCustomKeys = try encoded.decode()
    #expect(decoded.userName == "alice")
    #expect(decoded.isActive == true)
    #expect(decoded.createdAt == "2025-01-01")
  }

  @Test func complex() throws {
    let value: Complex = try json(
      """
      {"title":"Post","tags":["swift","json"],"type":"spot","address":{"street":"X","city":"Y","zip":1},"is_published":true}
      """
    ).decode()
    let encoded = JSON.encode(value)
    let decoded: Complex = try encoded.decode()
    #expect(decoded.title == "Post")
    #expect(decoded.tags == ["swift", "json"])
    #expect(decoded.type == .spot)
    #expect(decoded.address?.street == "X")
    #expect(decoded.isPublished == true)
  }

  @Test func arbitraryJSONNodeRoundTrip() throws {
    let value: WithArbitraryJSON = try json(
      """
      {"name":"Alice","metadata":{"x":1,"y":[true,"hello"]}}
      """
    ).decode()
    let encoded = JSON.encode(value)
    let decoded: WithArbitraryJSON = try encoded.decode()
    #expect(decoded.name == "Alice")
    #expect(decoded.metadata.description == value.metadata.description)
  }

  @Test func arbitraryJSONObjectRoundTrip() throws {
    let value: WithArbitraryObject = try json(
      """
      {"name":"Bob","config":{"debug":true,"level":5}}
      """
    ).decode()
    let encoded = JSON.encode(value)
    let decoded: WithArbitraryObject = try encoded.decode()
    #expect(decoded.name == "Bob")
    #expect(decoded.config.fields.count == 2)
    #expect(decoded.config.description == value.config.description)
  }
}

// MARK: - Round-trip Tests

@Suite("Integration: Round-trip")
struct RoundTripTests {
  @Test func unknownFieldsRoundTrip() throws {
    let original: WithUnknownFields = try json(
      """
      {"name":"Alice","age":30,"email":"alice@example.com","score":9.5,"active":true}
      """
    ).decode()
    #expect(original.name == "Alice")
    #expect(original.age == 30)

    // Re-encode and verify unknown fields survive
    let reEncoded = JSON.encode(original)
    let reDecoded: WithUnknownFields = try reEncoded.decode()
    #expect(reDecoded.name == "Alice")
    #expect(reDecoded.age == 30)
    #expect(reDecoded.unknownFields.fields.count == 3)
  }

  @Test func basicRoundTrip() throws {
    let original: BasicTypes = try json(
      """
      {"name":"Test","age":42,"score":3.14,"isActive":false}
      """
    ).decode()
    let encoded = JSON.encode(original)
    let decoded: BasicTypes = try encoded.decode()
    #expect(decoded.name == original.name)
    #expect(decoded.age == original.age)
    #expect(decoded.score == original.score)
    #expect(decoded.isActive == original.isActive)
  }

  @Test func nestedRoundTrip() throws {
    let original: WithNested = try json(
      """
      {"name":"Test","address":{"street":"Elm St","city":"Munich","zip":80331}}
      """
    ).decode()
    let encoded = JSON.encode(original)
    let decoded: WithNested = try encoded.decode()
    #expect(decoded.name == original.name)
    #expect(decoded.address.street == original.address.street)
    #expect(decoded.address.city == original.address.city)
    #expect(decoded.address.zip == original.address.zip)
  }

  @Test func complexRoundTrip() throws {
    let original: Complex = try json(
      """
      {"title":"Hello","tags":["x","y","z"],"type":"perpetual","is_published":false}
      """
    ).decode()
    let encoded = JSON.encode(original)
    let decoded: Complex = try encoded.decode()
    #expect(decoded.title == original.title)
    #expect(decoded.tags == original.tags)
    #expect(decoded.type == original.type)
    #expect(decoded.address == nil)
    #expect(decoded.isPublished == original.isPublished)
  }

  @Test func fieldOrderPreserved() throws {
    // Verify that encoding preserves field declaration order
    let value: BasicTypes = try json(
      """
      {"isActive":true,"name":"Z","score":1.0,"age":1}
      """
    ).decode()
    let encoded = JSON.encode(value)
    let jsonString = String(decoding: encoded.utf8, as: UTF8.self)
    // Fields should be in declaration order: name, age, score, isActive
    let nameIdx = jsonString.range(of: "\"name\"")!.lowerBound
    let ageIdx = jsonString.range(of: "\"age\"")!.lowerBound
    let scoreIdx = jsonString.range(of: "\"score\"")!.lowerBound
    let isActiveIdx = jsonString.range(of: "\"isActive\"")!.lowerBound
    #expect(nameIdx < ageIdx)
    #expect(ageIdx < scoreIdx)
    #expect(scoreIdx < isActiveIdx)
  }
}
