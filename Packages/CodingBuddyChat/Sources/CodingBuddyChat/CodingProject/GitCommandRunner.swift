import Foundation

struct GitCommandRunner: CodingProjectCommandRunning {
  func runGit(arguments: [String], in directoryURL: URL) async throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    process.arguments = arguments
    process.currentDirectoryURL = directoryURL
    process.standardInput = FileHandle.nullDevice

    let outputPipe = Pipe()
    process.standardOutput = outputPipe
    process.standardError = outputPipe

    let (terminationEvents, continuation) = AsyncStream.makeStream(of: Int32.self)
    process.terminationHandler = { finishedProcess in
      continuation.yield(finishedProcess.terminationStatus)
      continuation.finish()
    }

    do {
      try process.run()
    } catch {
      throw CodingProjectPreparationError.gitFailed(error.localizedDescription)
    }

    let status: Int32? = await withTaskCancellationHandler {
      var iterator = terminationEvents.makeAsyncIterator()
      return await iterator.next()
    } onCancel: {
      if process.isRunning {
        process.terminate()
      }
    }

    try Task.checkCancellation()
    let outputData = try outputPipe.fileHandleForReading.readToEnd() ?? Data()
    guard status == 0 else {
      let output = String(decoding: outputData, as: UTF8.self)
        .trimmingCharacters(in: .whitespacesAndNewlines)
      throw CodingProjectPreparationError.gitFailed(
        output.isEmpty ? "git exited with status \(status ?? -1)" : output
      )
    }
  }
}
