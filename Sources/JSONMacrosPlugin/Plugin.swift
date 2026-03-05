import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct JSONMacrosPlugin: CompilerPlugin {
  var providingMacros: [Macro.Type] {
    [
      JSONDecodableMacro.self,
      JSONEncodableMacro.self,
      JSONKeyMacro.self,
      JSONUnknownFieldsMacro.self,
    ]
  }
}
