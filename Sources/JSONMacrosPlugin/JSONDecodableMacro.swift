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

    let properties = extractStoredProperties(from: declaration.memberBlock.members)
    let unknownFieldsProp = properties.first(where: \.isUnknownFields)
    let regularProps = properties.filter { !$0.isUnknownFields }

    // Variable declarations
    var varDecls: [String] = []
    for prop in regularProps {
      if prop.isOptional {
        varDecls.append("var \(prop.name): \(prop.type) = nil")
      } else {
        varDecls.append("var \(prop.name): \(prop.type)?")
      }
    }
    if unknownFieldsProp != nil {
      varDecls.append("var unknownFields: [(key: JSON.Key, value: JSON.Node)] = []")
    }

    // Switch cases
    var switchCases: [String] = []
    for prop in regularProps {
      let key = prop.jsonKey ?? prop.name
      switchCases.append("case \"\(key)\": \(prop.name) = try field.decode()")
    }
    if unknownFieldsProp != nil {
      switchCases.append(
        "default: unknownFields.append((key: .init(rawValue: field.key), value: field.value))")
    } else {
      switchCases.append("default: break")
    }

    // Assignment statements
    var assignments: [String] = []
    for prop in regularProps {
      let key = prop.jsonKey ?? prop.name
      if prop.isOptional {
        assignments.append("self.\(prop.name) = \(prop.name)")
      } else {
        assignments.append("self.\(prop.name) = try \(prop.name).unwrap(key: \"\(key)\")")
      }
    }
    if let unknownFieldsProp {
      assignments.append("self.\(unknownFieldsProp.name) = .init(unknownFields)")
    }

    let varDeclsStr = varDecls.joined(separator: "\n        ")
    let switchCasesStr = switchCases.joined(separator: "\n            ")
    let assignmentsStr = assignments.joined(separator: "\n        ")
    let access = accessLevel(of: declaration)

    let initDecl: DeclSyntax = """
      \(raw: access)init(json: borrowing JSON.Node) throws {
          let object: JSON.Object = try .init(json: json)
          \(raw: varDeclsStr)
          for field: JSON.FieldDecoder<String> in copy object {
              switch field.key {
              \(raw: switchCasesStr)
              }
          }
          \(raw: assignmentsStr)
      }
      """

    return [initDecl]
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
