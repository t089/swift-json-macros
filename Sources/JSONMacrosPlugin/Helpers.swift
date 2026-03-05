import SwiftSyntax
import SwiftSyntaxMacros

struct StoredProperty {
  var name: String
  var type: TypeSyntax
  var isOptional: Bool
  var jsonKey: String?
  var isUnknownFields: Bool
}

func extractStoredProperties(
  from members: MemberBlockItemListSyntax
) -> [StoredProperty] {
  var properties: [StoredProperty] = []

  for member in members {
    guard let varDecl = member.decl.as(VariableDeclSyntax.self),
      varDecl.bindingSpecifier.tokenKind == .keyword(.var)
        || varDecl.bindingSpecifier.tokenKind == .keyword(.let)
    else {
      continue
    }

    // Skip computed properties (those with accessor blocks that aren't just stored)
    for binding in varDecl.bindings {
      if let accessorBlock = binding.accessorBlock {
        // If it has a code block accessor (get/set), it's computed
        switch accessorBlock.accessors {
        case .getter:
          continue
        case .accessors(let accessorList):
          let hasGetOrSet = accessorList.contains { accessor in
            accessor.accessorSpecifier.tokenKind == .keyword(.get)
              || accessor.accessorSpecifier.tokenKind == .keyword(.set)
          }
          if hasGetOrSet {
            continue
          }
        }
      }

      // Skip static properties
      let isStatic = varDecl.modifiers.contains { modifier in
        modifier.name.tokenKind == .keyword(.static)
          || modifier.name.tokenKind == .keyword(.class)
      }
      if isStatic {
        continue
      }

      guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
        let typeAnnotation = binding.typeAnnotation
      else {
        continue
      }

      let name = pattern.identifier.trimmedDescription
      let type = typeAnnotation.type.trimmed
      let isOptional = isOptionalType(type)
      let jsonKey = extractJSONKey(from: varDecl.attributes)
      let isUnknownFields = hasAttribute("JSONUnknownFields", in: varDecl.attributes)

      properties.append(
        StoredProperty(
          name: name,
          type: type,
          isOptional: isOptional,
          jsonKey: jsonKey,
          isUnknownFields: isUnknownFields
        ))
    }
  }

  return properties
}

private func isOptionalType(_ type: TypeSyntax) -> Bool {
  if type.is(OptionalTypeSyntax.self) {
    return true
  }
  if type.is(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
    return true
  }
  if let identifierType = type.as(IdentifierTypeSyntax.self),
    identifierType.name.trimmedDescription == "Optional"
  {
    return true
  }
  return false
}

private func extractJSONKey(from attributes: AttributeListSyntax) -> String? {
  for attribute in attributes {
    guard let attr = attribute.as(AttributeSyntax.self),
      let identifierType = attr.attributeName.as(IdentifierTypeSyntax.self),
      identifierType.name.trimmedDescription == "JSONKey",
      let arguments = attr.arguments?.as(LabeledExprListSyntax.self),
      let firstArg = arguments.first,
      let stringLiteral = firstArg.expression.as(StringLiteralExprSyntax.self),
      let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self)
    else {
      continue
    }
    return segment.content.trimmedDescription
  }
  return nil
}

private func hasAttribute(_ name: String, in attributes: AttributeListSyntax) -> Bool {
  attributes.contains { attribute in
    guard let attr = attribute.as(AttributeSyntax.self),
      let identifierType = attr.attributeName.as(IdentifierTypeSyntax.self)
    else {
      return false
    }
    return identifierType.name.trimmedDescription == name
  }
}
