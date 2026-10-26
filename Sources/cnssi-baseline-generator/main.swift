import Foundation
import CNSSIWorkflow

do {
    try await CNSSICommandLine.run(Array(CommandLine.arguments.dropFirst()))
} catch {
    FileHandle.standardError.write(Data("Error: \(error.localizedDescription)\n".utf8))
    exit(1)
}
