import JSONMacros
import Testing

// MARK: - Union test types

@JSONCodable
struct Circle {
  var type: String
  var radius: Double
}

@JSONCodable
struct Rectangle {
  var type: String
  var width: Double
  var height: Double
}

@JSONUnion("type")
enum Shape {
  case circle(Circle)
  case rectangle(Rectangle)
}

@JSONCodable
struct TextBlock {
  var type: String
  var text: String
}

@JSONCodable
struct ImageBlock {
  var type: String
  var url: String
}

@JSONUnion("type")
enum ContentBlock {
  case text(TextBlock)
  @JSONCase("img")
  case image(ImageBlock)
  @JSONDefaultCase
  case unknown(JSON.Node)
}

// Types using a computed discriminator (no stored `type`)

@JSONCodable
struct CircleV2 {
  var type: String { "circle" }
  var radius: Double
}

@JSONCodable
struct RectangleV2 {
  var type: String { "rectangle" }
  var width: Double
  var height: Double
}

@JSONUnion("type")
enum ShapeV2 {
  case circle(CircleV2)
  case rectangle(RectangleV2)
}

// Payload-less and mixed cases

@JSONCodable
struct ChatMessage {
  var type: String
  var text: String
}

@JSONUnion("type")
enum ChatEvent {
  case ping
  @JSONCase("pong")
  case heartbeat
  case message(ChatMessage)
}

// snake_case naming

@JSONCodable(naming: .snakeCase)
struct UserSnake {
  var firstName: String
  var lastName: String
  var phoneNumber: String?
}

// @JSONIgnore

@JSONCodable
struct WithIgnored {
  var name: String
  @JSONIgnore var derived: Int = 42

  init(name: String, derived: Int = 42) {
    self.name = name
    self.derived = derived
  }
}

private func parse(_ string: String) -> JSON {
  JSON(utf8: ArraySlice(string.utf8))
}

// MARK: - Tests

@Suite("Integration: Union")
struct UnionIntegrationTests {
  @Test func decodeCircle() throws {
    let shape: Shape = try parse(#"{"type":"circle","radius":5.0}"#).decode()
    guard case .circle(let circle) = shape else {
      Issue.record("Expected circle")
      return
    }
    #expect(circle.radius == 5.0)
    #expect(circle.type == "circle")
  }

  @Test func decodeRectangle() throws {
    let shape: Shape = try parse(#"{"type":"rectangle","width":10.0,"height":20.0}"#).decode()
    guard case .rectangle(let rect) = shape else {
      Issue.record("Expected rectangle")
      return
    }
    #expect(rect.width == 10.0)
    #expect(rect.height == 20.0)
  }

  @Test func unknownDiscriminatorThrows() throws {
    #expect(throws: (any Error).self) {
      let _: Shape = try parse(#"{"type":"triangle","sides":3}"#).decode()
    }
  }

  @Test func missingDiscriminatorThrows() throws {
    #expect(throws: (any Error).self) {
      let _: Shape = try parse(#"{"radius":5.0}"#).decode()
    }
  }

  @Test func customCaseName() throws {
    let block: ContentBlock = try parse(
      #"{"type":"img","url":"https://example.com/p.png"}"#
    ).decode()
    guard case .image(let img) = block else {
      Issue.record("Expected image")
      return
    }
    #expect(img.url == "https://example.com/p.png")
  }

  @Test func defaultCase() throws {
    let block: ContentBlock = try parse(
      #"{"type":"video","src":"movie.mp4"}"#
    ).decode()
    guard case .unknown = block else {
      Issue.record("Expected unknown")
      return
    }
  }

  @Test func unionRoundTrip() throws {
    let original: Shape = try parse(#"{"type":"circle","radius":3.14}"#).decode()
    let encoded = JSON.encode(original)
    let decoded: Shape = try encoded.decode()
    guard case .circle(let circle) = decoded else {
      Issue.record("Expected circle")
      return
    }
    #expect(circle.radius == 3.14)
  }

  @Test func payloadlessCase() throws {
    let event: ChatEvent = try parse(#"{"type":"ping"}"#).decode()
    guard case .ping = event else {
      Issue.record("Expected ping")
      return
    }

    let encoded = JSON.encode(event)
    let jsonString = String(decoding: encoded.utf8, as: UTF8.self)
    #expect(jsonString.contains(#""type":"ping""#))

    let decoded: ChatEvent = try encoded.decode()
    guard case .ping = decoded else {
      Issue.record("Expected ping after round-trip")
      return
    }
  }

  @Test func payloadlessCaseWithCustomName() throws {
    let event: ChatEvent = try parse(#"{"type":"pong"}"#).decode()
    guard case .heartbeat = event else {
      Issue.record("Expected heartbeat")
      return
    }

    let encoded = JSON.encode(event)
    let jsonString = String(decoding: encoded.utf8, as: UTF8.self)
    #expect(jsonString.contains(#""type":"pong""#))
  }

  @Test func payloadlessAndPayloadMixed() throws {
    let msg: ChatEvent = try parse(#"{"type":"message","text":"hi"}"#).decode()
    guard case .message(let content) = msg else {
      Issue.record("Expected message")
      return
    }
    #expect(content.text == "hi")
  }

  @Test func computedDiscriminatorRoundTrip() throws {
    let shape: ShapeV2 = try parse(#"{"type":"circle","radius":3.14}"#).decode()
    guard case .circle(let circle) = shape else {
      Issue.record("Expected circle")
      return
    }
    #expect(circle.radius == 3.14)
    #expect(circle.type == "circle")

    let encoded = JSON.encode(shape)
    let jsonString = String(decoding: encoded.utf8, as: UTF8.self)
    #expect(jsonString.contains(#""type":"circle""#))
    #expect(jsonString.contains(#""radius":3.14"#))

    let redecoded: ShapeV2 = try encoded.decode()
    guard case .circle(let again) = redecoded else {
      Issue.record("Expected circle")
      return
    }
    #expect(again.radius == 3.14)
  }
}

@Suite("Integration: Naming")
struct NamingIntegrationTests {
  @Test func snakeCaseRoundTrip() throws {
    let user: UserSnake = try parse(
      #"{"first_name":"Ada","last_name":"Lovelace","phone_number":"123"}"#
    ).decode()
    #expect(user.firstName == "Ada")
    #expect(user.lastName == "Lovelace")
    #expect(user.phoneNumber == "123")

    let encoded = JSON.encode(user)
    let jsonString = String(decoding: encoded.utf8, as: UTF8.self)
    #expect(jsonString.contains(#""first_name":"Ada""#))
    #expect(jsonString.contains(#""last_name":"Lovelace""#))
    #expect(jsonString.contains(#""phone_number":"123""#))
  }
}

@Suite("Integration: JSONIgnore")
struct JSONIgnoreIntegrationTests {
  @Test func ignoredFieldNotDecoded() throws {
    let value: WithIgnored = try parse(#"{"name":"Ada","derived":99}"#).decode()
    #expect(value.name == "Ada")
    #expect(value.derived == 42)
  }

  @Test func ignoredFieldNotEncoded() throws {
    let value = WithIgnored(name: "Ada")
    let encoded = JSON.encode(value)
    let jsonString = String(decoding: encoded.utf8, as: UTF8.self)
    #expect(jsonString.contains(#""name":"Ada""#))
    #expect(!jsonString.contains("derived"))
  }
}
