import JSONMacros
import Testing

#if canImport(FoundationEssentials)
  import FoundationEssentials
#else
  import Foundation
#endif

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
  case unknown(JSONPrimitive)
}

private func decode<T: JSONDecodable>(_ type: T.Type, from string: String) throws -> T {
  let decoder = NewJSONDecoder()
  return try decoder.decode(type, from: Data(string.utf8))
}

private func encode<T: JSONEncodable>(_ value: borrowing T) throws -> Data {
  let encoder = NewJSONEncoder()
  return try encoder.encode(value)
}

// MARK: - Union Tests

@Suite("Integration: Union")
struct UnionTests {
  @Test func decodeCircle() throws {
    let shape = try decode(
      Shape.self,
      from: """
        {"type":"circle","radius":5.0}
        """)
    guard case .circle(let circle) = shape else {
      Issue.record("Expected circle")
      return
    }
    #expect(circle.radius == 5.0)
  }

  @Test func decodeRectangle() throws {
    let shape = try decode(
      Shape.self,
      from: """
        {"type":"rectangle","width":10.0,"height":20.0}
        """)
    guard case .rectangle(let rect) = shape else {
      Issue.record("Expected rectangle")
      return
    }
    #expect(rect.width == 10.0)
    #expect(rect.height == 20.0)
  }

  @Test func unknownTypeThrows() throws {
    #expect(throws: (any Error).self) {
      try decode(
        Shape.self,
        from: """
          {"type":"triangle","sides":3}
          """)
    }
  }

  @Test func customCaseName() throws {
    let block = try decode(
      ContentBlock.self,
      from: """
        {"type":"img","url":"https://example.com/pic.png"}
        """)
    guard case .image(let img) = block else {
      Issue.record("Expected image")
      return
    }
    #expect(img.url == "https://example.com/pic.png")
  }

  @Test func defaultCase() throws {
    let block = try decode(
      ContentBlock.self,
      from: """
        {"type":"video","src":"movie.mp4"}
        """)
    guard case .unknown = block else {
      Issue.record("Expected unknown")
      return
    }
  }

  @Test func unionRoundTrip() throws {
    let shape = try decode(
      Shape.self,
      from: """
        {"type":"circle","radius":3.14}
        """)
    let data = try encode(shape)
    let decoded = try NewJSONDecoder().decode(Shape.self, from: data)
    guard case .circle(let circle) = decoded else {
      Issue.record("Expected circle")
      return
    }
    #expect(circle.radius == 3.14)
  }
}
