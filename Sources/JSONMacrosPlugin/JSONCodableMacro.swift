import SwiftSyntax
import SwiftSyntaxMacros

public struct JSONCodableMacro {}

extension JSONCodableMacro: MemberMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    try JSONDecodableMacro.expansion(
      of: node, providingMembersOf: declaration, conformingTo: protocols, in: context)
      + JSONEncodableMacro.expansion(
        of: node, providingMembersOf: declaration, conformingTo: protocols, in: context)
  }
}

extension JSONCodableMacro: ExtensionMacro {
  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    try JSONDecodableMacro.expansion(
      of: node, attachedTo: declaration, providingExtensionsOf: type,
      conformingTo: protocols, in: context)
      + JSONEncodableMacro.expansion(
        of: node, attachedTo: declaration, providingExtensionsOf: type,
        conformingTo: protocols, in: context)
  }
}
