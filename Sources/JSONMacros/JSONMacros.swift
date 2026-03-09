@_exported import NewCodable

public enum JSONNamingStrategy {
  case camelCase
  case snakeCase
  case upperSnakeCase
}

@attached(member, names: named(encode(to:)))
@attached(extension, conformances: JSONEncodable)
public macro JSONEncodable(naming: JSONNamingStrategy = .camelCase) =
  #externalMacro(module: "JSONMacrosPlugin", type: "JSONEncodableMacro")

@attached(member, names: named(decode(from:)))
@attached(extension, conformances: JSONDecodable)
public macro JSONDecodable(naming: JSONNamingStrategy = .camelCase) =
  #externalMacro(module: "JSONMacrosPlugin", type: "JSONDecodableMacro")

@attached(member, names: named(encode(to:)), named(decode(from:)))
@attached(extension, conformances: JSONEncodable, JSONDecodable)
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

@attached(member, names: named(encode(to:)), named(decode(from:)))
@attached(extension, conformances: JSONEncodable, JSONDecodable)
public macro JSONUnion(_ discriminator: String, naming: JSONNamingStrategy = .snakeCase) =
  #externalMacro(module: "JSONMacrosPlugin", type: "JSONUnionMacro")

@attached(peer)
public macro JSONCase(_ names: String...) =
  #externalMacro(module: "JSONMacrosPlugin", type: "JSONCaseMacro")

@attached(peer)
public macro JSONDefaultCase() =
  #externalMacro(module: "JSONMacrosPlugin", type: "JSONDefaultCaseMacro")

extension Optional {
  public func unwrap(key: some Sendable) throws(CodingError.Decoding) -> Wrapped {
    guard let self else {
      throw CodingError.dataCorrupted(debugDescription: "Missing required field: \(key)")
    }
    return self
  }
}
