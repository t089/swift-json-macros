import SwiftSyntax
import SwiftSyntaxMacros

public struct JSONDecodableMacro {}

extension JSONDecodableMacro: MemberMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard declaration.is(StructDeclSyntax.self) || declaration.is(ClassDeclSyntax.self) else {
      context.addDiagnostics(
        from: MacroError.notAStructOrClass, node: node)
      return []
    }

    let naming = extractNamingStrategy(from: node) ?? .camelCase
    let properties = extractStoredProperties(from: declaration.memberBlock.members)
    let unknownFieldsProp = properties.first(where: \.isUnknownFields)
    let regularProps = properties.filter { !$0.isUnknownFields }

    // Variable declarations
    var varDecls: [String] = []
    for prop in regularProps {
      varDecls.append("var \(prop.name): \(prop.type)?")
    }
    if unknownFieldsProp != nil {
      varDecls.append(
        "var unknownFields: [(key: String, value: JSONPrimitive)] = []")
    }

    // Switch cases
    var switchCases: [String] = []
    for prop in regularProps {
      let key = prop.jsonKey ?? naming.convert(prop.name)
      if prop.isOptional {
        let baseType = prop.wrappedType ?? "\(prop.type)"
        switchCases.append(
          "case \"\(key)\": if try !valueDecoder.decodeNil() { \(prop.name) = try valueDecoder.decode(\(baseType).self) }"
        )
      } else {
        switchCases.append(
          "case \"\(key)\": \(prop.name) = try valueDecoder.decode(\(prop.type).self)")
      }
    }
    if unknownFieldsProp != nil {
      switchCases.append(
        "default: unknownFields.append((key: key, value: try valueDecoder.decode(JSONPrimitive.self)))"
      )
    } else {
      switchCases.append("default: break")
    }

    // Return expression parts
    var initArgs: [String] = []
    for prop in regularProps {
      let key = prop.jsonKey ?? naming.convert(prop.name)
      if prop.isOptional {
        initArgs.append("\(prop.name): \(prop.name) ?? nil")
      } else {
        initArgs.append(
          "\(prop.name): try \(prop.name).unwrap(key: \"\(key)\")")
      }
    }
    if let unknownFieldsProp {
      initArgs.append("\(unknownFieldsProp.name): unknownFields")
    }

    let varDeclsStr = varDecls.joined(separator: "\n            ")
    let switchCasesStr = switchCases.joined(separator: "\n                ")
    let initArgsStr = initArgs.joined(separator: ",\n                ")
    let access = accessLevel(of: declaration)
    let typeName = typeNameOf(declaration)

    let decl: DeclSyntax = """
      \(raw: access)static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
          try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
              \(raw: varDeclsStr)
              try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                  switch key {
                  \(raw: switchCasesStr)
                  }
                  return false
              }
              return \(raw: typeName)(
                  \(raw: initArgsStr)
              )
          }
      }
      """

    return [decl]
  }
}

extension JSONDecodableMacro: ExtensionMacro {
  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    if protocols.isEmpty {
      return []
    }

    let extensionDecl: DeclSyntax = """
      extension \(type.trimmed): JSONDecodable {}
      """

    return [extensionDecl.cast(ExtensionDeclSyntax.self)]
  }
}

enum MacroError: Error, CustomStringConvertible {
  case notAStructOrClass

  var description: String {
    switch self {
    case .notAStructOrClass:
      return "@JSONDecodable / @JSONEncodable can only be applied to structs or classes"
    }
  }
}
