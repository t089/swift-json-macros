import SwiftSyntax
import SwiftSyntaxMacros

public struct JSONEncodableMacro {}

extension JSONEncodableMacro: MemberMacro {
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

    var encodingStatements: [String] = []
    for prop in regularProps {
      let key = prop.jsonKey ?? naming.convert(prop.name)
      if prop.isOptional {
        encodingStatements.append(
          """
          if let value = self.\(prop.name) {
                      try structEncoder.encode(key: \"\(key)\", value: value)
                  }
          """)
      } else {
        encodingStatements.append(
          "try structEncoder.encode(key: \"\(key)\", value: self.\(prop.name))")
      }
    }
    if let unknownFieldsProp {
      encodingStatements.append(
        """
        for (key, value) in self.\(unknownFieldsProp.name) {
                    try structEncoder.encode(key: key, value: value)
                }
        """)
    }

    let encodingStatementsStr = encodingStatements.joined(separator: "\n            ")
    let access = accessLevel(of: declaration)

    let encodeDecl: DeclSyntax = """
      \(raw: access)func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
          try encoder.encodeStructFields(count: nil) { structEncoder throws(CodingError.Encoding) in
              \(raw: encodingStatementsStr)
          }
      }
      """

    return [encodeDecl]
  }
}

extension JSONEncodableMacro: ExtensionMacro {
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
      extension \(type.trimmed): JSONEncodable {}
      """

    return [extensionDecl.cast(ExtensionDeclSyntax.self)]
  }
}
