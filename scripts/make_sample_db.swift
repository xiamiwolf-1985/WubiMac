import Foundation
import WubiEngine

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "wubi86.db"
try WubiDictBuilder.buildSample(to: outputPath)
print("Database built: \(outputPath)")
