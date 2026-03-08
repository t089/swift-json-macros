import SwiftSyntax
import SwiftSyntaxMacros

public struct JSONUnionMacro {}

struct UnionCase {
  var caseName: String
  var associatedType: String
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

    let decodeDecl = generateDecode(
      cases: cases, discriminatorKey: discriminatorKey, access: access)
    let encodeDecl = generateEncode(cases: cases, access: access)

    return [decodeDecl, encodeDecl]
  }

  private static func generateDecode(
    cases: [UnionCase], discriminatorKey: String, access: String
  ) -> DeclSyntax {
    let defaultCase = cases.first(where: \.isDefault)
    let regularCases = cases.filter { !$0.isDefault }

    var switchCases: [String] = []
    for c in regularCases {
      let patterns = c.typeStrings.map { "\"\($0)\"" }.joined(separator: ", ")
      switchCases.append(
        """
        case \(patterns):
                        var d = JSONPrimitiveDecoder(value: primitive)
                        return .\(c.caseName)(try d.decode(\(c.associatedType).self))
        """)
    }

    let defaultBranch: String
    if let defaultCase {
      defaultBranch = """
        default:
                        var d = JSONPrimitiveDecoder(value: primitive)
                        return .\(defaultCase.caseName)(try d.decode(\(defaultCase.associatedType).self))
        """
    } else {
      defaultBranch = """
        default:
                        throw CodingError.dataCorrupted(debugDescription: "Unknown \\(\"\(discriminatorKey)\") value: \\(type ?? "nil")")
        """
    }
    switchCases.append(defaultBranch)

    let switchCasesStr = switchCases.joined(separator: "\n                ")

    return """
      \(raw: access)static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
          try decoder.decodeStruct { s throws(CodingError.Decoding) in
              var type: String?
              var fields: [(key: String, value: JSONPrimitive)] = []
              try s.decodeEachKeyAndValue { (key, valueDecoder: inout _) throws(CodingError.Decoding) -> Void in
                  if key == \"\(raw: discriminatorKey)\" {
                      type = try valueDecoder.decode(String.self)
                      fields.append((key: key, value: .string(type!)))
                  } else {
                      fields.append((key: key, value: try valueDecoder.decodeJSONPrimitive()))
                  }
              }
              let primitive = JSONPrimitive.dictionary(fields)
              switch type {
              \(raw: switchCasesStr)
              }
          }
      }
      """
  }

  private static func generateEncode(cases: [UnionCase], access: String) -> DeclSyntax {
    var switchCases: [String] = []
    for c in cases {
      switchCases.append(
        "case .\(c.caseName)(let content): try content.encode(to: &encoder)")
    }
    let switchCasesStr = switchCases.joined(separator: "\n            ")

    return """
      \(raw: access)func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
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

      guard let paramClause = element.parameterClause,
        let firstParam = paramClause.parameters.first
      else {
        continue
      }

      let associatedType = firstParam.type.trimmedDescription
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
