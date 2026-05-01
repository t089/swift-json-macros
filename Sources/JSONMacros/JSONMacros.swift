@_exported import JSON

public enum JSONNamingStrategy {
  case camelCase
  case snakeCase
  case upperSnakeCase
}

@attached(member, names: named(init(json:)))
@attached(extension, conformances: JSONDecodable)
public macro JSONDecodable(naming: JSONNamingStrategy = .camelCase) =
  #externalMacro(module: "JSONMacrosPlugin", type: "JSONDecodableMacro")

@attached(member, names: named(encode(to:)))
@attached(extension, conformances: JSONEncodable)
public macro JSONEncodable(naming: JSONNamingStrategy = .camelCase) =
  #externalMacro(module: "JSONMacrosPlugin", type: "JSONEncodableMacro")

@attached(member, names: named(init(json:)), named(encode(to:)))
@attached(extension, conformances: JSONDecodable, JSONEncodable)
public macro JSONCodable(naming: JSONNamingStrategy = .camelCase) =
  #externalMacro(module: "JSONMacrosPlugin", type: "JSONCodableMacro")

@attached(peer)
public macro JSONKey(_ name: String) =
  #externalMacro(module: "JSONMacrosPlugin", type: "JSONKeyMacro")

@attached(peer)
public macro JSONIgnore() =
  #externalMacro(module: "JSONMacrosPlugin", type: "JSONIgnoreMacro")

@attached(peer)
public macro JSONUnknownFields() =
  #externalMacro(module: "JSONMacrosPlugin", type: "JSONUnknownFieldsMacro")

@attached(member, names: named(init(json:)), named(encode(to:)))
@attached(extension, conformances: JSONDecodable, JSONEncodable)
public macro JSONUnion(_ discriminator: String, naming: JSONNamingStrategy = .snakeCase) =
  #externalMacro(module: "JSONMacrosPlugin", type: "JSONUnionMacro")

@attached(peer)
public macro JSONCase(_ names: String...) =
  #externalMacro(module: "JSONMacrosPlugin", type: "JSONCaseMacro")

@attached(peer)
public macro JSONDefaultCase() =
  #externalMacro(module: "JSONMacrosPlugin", type: "JSONDefaultCaseMacro")

extension Optional {
  public func unwrap(key: some Sendable) throws -> Wrapped {
    guard let self else { throw JSON.ObjectKeyError.undefined(key) }
    return self
  }
}

// MARK: - Retroactive conformances for AST types

extension JSON.Node: @retroactive JSONDecodable {
  public init(json: borrowing JSON.Node) throws {
    self = copy json
  }
}

extension JSON.Node: @retroactive JSONEncodable {
  public func encode(to json: inout JSON) {
    json.utf8 += self.description.utf8
  }
}

extension JSON.Object: @retroactive JSONEncodable {
  public func encode(to json: inout JSON) {
    json.utf8 += self.description.utf8
  }
}

extension JSON.Array: @retroactive JSONEncodable {
  public func encode(to json: inout JSON) {
    json.utf8 += self.description.utf8
  }
}
