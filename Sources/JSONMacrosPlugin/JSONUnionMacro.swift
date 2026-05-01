import SwiftSyntax
import SwiftSyntaxMacros

public struct JSONUnionMacro {}

struct UnionCase {
  var caseName: String
  var associatedType: String?
  var typeStrings: [String]
  var isDefault: Bool
}

extension JSONUnionMacro: MemberMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard let enumDecl = declaration.as(EnumDeclSyntax.self) else {
      context.addDiagnostics(from: UnionMacroError.notAnEnum, node: node)
      return []
    }

    guard let discriminatorKey = extractDiscriminatorKey(from: node) else {
      context.addDiagnostics(from: UnionMacroError.missingDiscriminator, node: node)
      return []
    }

    let naming = extractNamingStrategy(from: node) ?? .snakeCase
    let cases = extractUnionCases(from: enumDecl.memberBlock.members, naming: naming)
    let access = accessLevel(of: declaration)

    let initDecl = generateDecode(
      cases: cases, discriminatorKey: discriminatorKey, access: access)
    let encodeDecl = generateEncode(
      cases: cases, discriminatorKey: discriminatorKey, access: access)

    return [initDecl, encodeDecl]
  }

  private static func generateDecode(
    cases: [UnionCase], discriminatorKey: String, access: String
  ) -> DeclSyntax {
    let defaultCase = cases.first(where: \.isDefault)
    let regularCases = cases.filter { !$0.isDefault }

    var switchCases: [String] = []
    for c in regularCases {
      let patterns = c.typeStrings.map { "\"\($0)\"" }.joined(separator: ", ")
      let assignment =
        c.associatedType == nil
        ? "self = .\(c.caseName)"
        : "self = .\(c.caseName)(try .init(json: json))"
      switchCases.append("case \(patterns): \(assignment)")
    }

    if let defaultCase {
      let assignment =
        defaultCase.associatedType == nil
        ? "self = .\(defaultCase.caseName)"
        : "self = .\(defaultCase.caseName)(try .init(json: json))"
      switchCases.append("default: \(assignment)")
    } else {
      switchCases.append(
        "case let other?: throw JSON.ValueError<String, Self>(invalid: other)")
      switchCases.append(
        "case nil: throw JSON.ObjectKeyError<String>.undefined(\"\(discriminatorKey)\")")
    }

    let switchCasesStr = switchCases.joined(separator: "\n            ")

    return """
      \(raw: access)init(json: borrowing JSON.Node) throws {
          let object: JSON.Object = try .init(json: json)
          var discriminator: String? = nil
          for field: JSON.FieldDecoder<String> in copy object {
              if field.key == "\(raw: discriminatorKey)" {
                  discriminator = try field.decode()
                  break
              }
          }
          switch discriminator {
          \(raw: switchCasesStr)
          }
      }
      """
  }

  private static func generateEncode(
    cases: [UnionCase], discriminatorKey: String, access: String
  ) -> DeclSyntax {
    var switchCases: [String] = []
    for c in cases {
      if c.associatedType == nil {
        // Payload-less case: emit just the discriminator field.
        let typeString = c.typeStrings.first ?? c.caseName
        switchCases.append(
          """
          case .\(c.caseName):
                  json(Any.self) { encoder in
                      encoder["\(discriminatorKey)"] = "\(typeString)"
                  }
          """)
      } else {
        switchCases.append(
          "case .\(c.caseName)(let content): content.encode(to: &json)")
      }
    }
    let switchCasesStr = switchCases.joined(separator: "\n        ")

    return """
      \(raw: access)func encode(to json: inout JSON) {
          switch self {
          \(raw: switchCasesStr)
          }
      }
      """
  }
}

extension JSONUnionMacro: ExtensionMacro {
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
      extension \(type.trimmed): JSONDecodable, JSONEncodable {}
      """

    return [extensionDecl.cast(ExtensionDeclSyntax.self)]
  }
}

// MARK: - Helpers

private func extractDiscriminatorKey(from node: AttributeSyntax) -> String? {
  guard let arguments = node.arguments?.as(LabeledExprListSyntax.self),
    let firstArg = arguments.first,
    let stringLiteral = firstArg.expression.as(StringLiteralExprSyntax.self),
    let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self)
  else {
    return nil
  }
  return segment.content.trimmedDescription
}

private func extractUnionCases(
  from members: MemberBlockItemListSyntax,
  naming: NamingStrategy
) -> [UnionCase] {
  var cases: [UnionCase] = []

  for member in members {
    guard let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) else {
      continue
    }

    for element in caseDecl.elements {
      let caseName = element.name.trimmedDescription

      let associatedType = element.parameterClause?.parameters.first?.type.trimmedDescription
      let isDefault = hasAttribute("JSONDefaultCase", in: caseDecl.attributes)
      let customNames = extractCaseNames(from: caseDecl.attributes)

      let typeStrings: [String]
      if let customNames, !customNames.isEmpty {
        typeStrings = customNames
      } else if isDefault {
        typeStrings = []
      } else {
        typeStrings = [naming.convert(caseName)]
      }

      cases.append(
        UnionCase(
          caseName: caseName,
          associatedType: associatedType,
          typeStrings: typeStrings,
          isDefault: isDefault
        ))
    }
  }

  return cases
}

private func extractCaseNames(from attributes: AttributeListSyntax) -> [String]? {
  for attribute in attributes {
    guard let attr = attribute.as(AttributeSyntax.self),
      let identifierType = attr.attributeName.as(IdentifierTypeSyntax.self),
      identifierType.name.trimmedDescription == "JSONCase",
      let arguments = attr.arguments?.as(LabeledExprListSyntax.self)
    else {
      continue
    }

    var names: [String] = []
    for arg in arguments {
      if let stringLiteral = arg.expression.as(StringLiteralExprSyntax.self),
        let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self)
      {
        names.append(segment.content.trimmedDescription)
      }
    }
    return names
  }
  return nil
}

// MARK: - Errors

enum UnionMacroError: Error, CustomStringConvertible {
  case notAnEnum
  case missingDiscriminator

  var description: String {
    switch self {
    case .notAnEnum:
      return "@JSONUnion can only be applied to enums"
    case .missingDiscriminator:
      return "@JSONUnion requires a discriminator key name, e.g. @JSONUnion(\"type\")"
    }
  }
}
