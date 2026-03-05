import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct JSONMacrosPlugin: CompilerPlugin {
  var providingMacros: [Macro.Type] {
    [
      JSONCodableMacro.self,
      JSONDecodableMacro.self,
      JSONEncodableMacro.self,
      JSONKeyMacro.self,
      JSONUnknownFieldsMacro.self,
    ]
  }
}
