import SwiftSyntax
import SwiftSyntaxMacros

struct StoredProperty {
  var name: String
  var type: TypeSyntax
  var isOptional: Bool
  var wrappedType: String?
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
      let wrappedType = extractWrappedType(type)
      let jsonKey = extractJSONKey(from: varDecl.attributes)
      let isUnknownFields = hasAttribute("JSONUnknownFields", in: varDecl.attributes)

      properties.append(
        StoredProperty(
          name: name,
          type: type,
          isOptional: isOptional,
          wrappedType: wrappedType,
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

private func extractWrappedType(_ type: TypeSyntax) -> String? {
  if let optionalType = type.as(OptionalTypeSyntax.self) {
    return optionalType.wrappedType.trimmedDescription
  }
  if let optionalType = type.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
    return optionalType.wrappedType.trimmedDescription
  }
  if let identifierType = type.as(IdentifierTypeSyntax.self),
    identifierType.name.trimmedDescription == "Optional",
    let genericArgs = identifierType.genericArgumentClause?.arguments,
    let firstArg = genericArgs.first
  {
    return firstArg.argument.trimmedDescription
  }
  return nil
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

func accessLevel(of declaration: some DeclGroupSyntax) -> String {
  for modifier in declaration.modifiers {
    switch modifier.name.tokenKind {
    case .keyword(.public), .keyword(.open), .keyword(.package):
      return modifier.name.trimmedDescription + " "
    default:
      continue
    }
  }
  return ""
}

func hasAttribute(_ name: String, in attributes: AttributeListSyntax) -> Bool {
  attributes.contains { attribute in
    guard let attr = attribute.as(AttributeSyntax.self),
      let identifierType = attr.attributeName.as(IdentifierTypeSyntax.self)
    else {
      return false
    }
    return identifierType.name.trimmedDescription == name
  }
}

// MARK: - Naming Strategy

enum NamingStrategy {
  case camelCase
  case snakeCase
  case upperSnakeCase

  func convert(_ name: String) -> String {
    switch self {
    case .camelCase:
      return name
    case .snakeCase:
      return camelCaseToSnakeCase(name)
    case .upperSnakeCase:
      return camelCaseToSnakeCase(name).uppercased()
    }
  }
}

func extractNamingStrategy(from node: AttributeSyntax, label: String = "naming") -> NamingStrategy?
{
  guard let arguments = node.arguments?.as(LabeledExprListSyntax.self) else {
    return nil
  }
  for arg in arguments {
    guard arg.label?.trimmedDescription == label,
      let memberAccess = arg.expression.as(MemberAccessExprSyntax.self)
    else {
      continue
    }
    switch memberAccess.declName.baseName.trimmedDescription {
    case "camelCase":
      return .camelCase
    case "snakeCase":
      return .snakeCase
    case "upperSnakeCase":
      return .upperSnakeCase
    default:
      return nil
    }
  }
  return nil
}

private func camelCaseToSnakeCase(_ input: String) -> String {
  var result = ""
  for (i, char) in input.enumerated() {
    if char.isUppercase {
      if i > 0 {
        result.append("_")
      }
      result.append(char.lowercased())
    } else {
      result.append(char)
    }
  }
  return result
}

func typeNameOf(_ declaration: some DeclGroupSyntax) -> String {
  if let structDecl = declaration.as(StructDeclSyntax.self) {
    return structDecl.name.trimmedDescription
  }
  if let classDecl = declaration.as(ClassDeclSyntax.self) {
    return classDecl.name.trimmedDescription
  }
  return "Self"
}
