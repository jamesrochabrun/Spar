//
//  CodeRunnerService.swift
//  InterviewKit
//
//  Compiles and runs a solution file so the candidate can verify their code
//  before grading. Swift, Python, JavaScript, and TypeScript are supported;
//  TypeScript gets a `tsc --noEmit` type-check first when tsc is installed.
//

import Foundation

// MARK: - CodeRunLanguage

public enum CodeRunLanguage: String, CaseIterable, Sendable {
  case swift
  case python
  case javascript
  case typescript

  public static func detect(fileExtension: String) -> CodeRunLanguage? {
    switch fileExtension.lowercased() {
    case "swift": return .swift
    case "py": return .python
    case "js", "mjs", "cjs": return .javascript
    case "ts", "mts": return .typescript
    default: return nil
    }
  }

  public var displayName: String {
    switch self {
    case .swift: return "Swift"
    case .python: return "Python"
    case .javascript: return "JavaScript"
    case .typescript: return "TypeScript"
    }
  }
}

// MARK: - CodeRunResult

public struct CodeRunResult: Sendable, Equatable {
  public let language: CodeRunLanguage
  /// Human-readable command that produced this result, e.g. "swift solution.swift".
  public let commandLine: String
  public let exitCode: Int32
  public let standardOutput: String
  public let standardError: String
  public let duration: TimeInterval
  public let didTimeOut: Bool

  public var succeeded: Bool { exitCode == 0 && !didTimeOut }

  public init(
    language: CodeRunLanguage,
    commandLine: String,
    exitCode: Int32,
    standardOutput: String,
    standardError: String,
    duration: TimeInterval,
    didTimeOut: Bool
  ) {
    self.language = language
    self.commandLine = commandLine
    self.exitCode = exitCode
    self.standardOutput = standardOutput
    self.standardError = standardError
    self.duration = duration
    self.didTimeOut = didTimeOut
  }
}

// MARK: - CodeRunnerError

public enum CodeRunnerError: Error, LocalizedError, Equatable {
  case unsupportedFileType(fileExtension: String)
  case toolNotFound(language: CodeRunLanguage, candidates: [String])

  public var errorDescription: String? {
    switch self {
    case .unsupportedFileType(let fileExtension):
      return "Running .\(fileExtension) files isn't supported yet."
    case .toolNotFound(let language, let candidates):
      let tools = candidates.joined(separator: ", ")
      return "No \(language.displayName) runtime found. Install one of: \(tools)."
    }
  }
}

// MARK: - CodeRunning

public protocol CodeRunning: Sendable {
  /// The language a file would run as, or nil when the file type is unsupported.
  func language(forFileExtension fileExtension: String) -> CodeRunLanguage?
  /// Compiles and runs the file, returning captured output. Cancelling the
  /// surrounding task terminates the process.
  func run(fileURL: URL) async throws -> CodeRunResult
}

extension CodeRunning {
  public func language(forFileExtension fileExtension: String) -> CodeRunLanguage? {
    CodeRunLanguage.detect(fileExtension: fileExtension)
  }
}

// MARK: - ProcessCodeRunner

public struct ProcessCodeRunner: CodeRunning {

  /// Homebrew and version-manager paths first so a user-installed toolchain
  /// wins over system stubs. GUI apps launch with a minimal PATH, so nvm/volta
  /// installs would otherwise be invisible. Cached: the nvm scan touches the
  /// filesystem and this is read from view initializers.
  public static let defaultSearchPaths: [String] = {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    return [
      "/opt/homebrew/bin",
      "/usr/local/bin",
    ]
    + nvmNodeBinPaths(home: home)
    + [
      "\(home)/.volta/bin",
      "\(home)/.bun/bin",
      "\(home)/.deno/bin",
      "\(home)/.local/bin",
      "/usr/bin",
      "/bin",
    ]
  }()

  /// Installed nvm node versions, newest first.
  static func nvmNodeBinPaths(home: String) -> [String] {
    let versionsDirectory = "\(home)/.nvm/versions/node"
    guard let versions = try? FileManager.default.contentsOfDirectory(atPath: versionsDirectory) else {
      return []
    }
    func components(_ version: String) -> [Int] {
      version.trimmingCharacters(in: CharacterSet(charactersIn: "v"))
        .split(separator: ".")
        .map { Int($0) ?? 0 }
    }
    return versions
      .filter { $0.hasPrefix("v") }
      .sorted { components($0).lexicographicallyPrecedes(components($1)) }
      .reversed()
      .map { "\(versionsDirectory)/\($0)/bin" }
  }

  private let effectiveSearchPaths: [String]
  private let timeout: TimeInterval
  private let maxOutputBytes: Int

  /// - Parameters:
  ///   - searchPaths: directories probed for toolchains, ahead of the current PATH.
  ///   - timeout: wall-clock budget per process before it is terminated.
  ///   - maxOutputBytes: per-stream capture cap; extra output is discarded.
  public init(
    searchPaths: [String] = ProcessCodeRunner.defaultSearchPaths,
    timeout: TimeInterval = 30,
    maxOutputBytes: Int = 65_536
  ) {
    let pathEntries = (ProcessInfo.processInfo.environment["PATH"] ?? "")
      .split(separator: ":")
      .map(String.init)
    var seen = Set<String>()
    effectiveSearchPaths = (searchPaths + pathEntries).filter { seen.insert($0).inserted }
    self.timeout = timeout
    self.maxOutputBytes = maxOutputBytes
  }

  public func run(fileURL: URL) async throws -> CodeRunResult {
    let fileExtension = fileURL.pathExtension
    guard let language = CodeRunLanguage.detect(fileExtension: fileExtension) else {
      throw CodeRunnerError.unsupportedFileType(fileExtension: fileExtension)
    }

    let workingDirectory = fileURL.deletingLastPathComponent()
    for invocation in try invocations(for: language, fileURL: fileURL) {
      let result = try await execute(invocation, language: language, workingDirectory: workingDirectory)
      // A passing check phase (e.g. tsc --noEmit) is silent; move on to the run.
      if invocation.isCheck && result.succeeded { continue }
      return result
    }
    throw CodeRunnerError.toolNotFound(language: language, candidates: [])
  }

  // MARK: - Execution planning

  private struct Invocation {
    let executable: URL
    let arguments: [String]
    let isCheck: Bool
  }

  private func invocations(for language: CodeRunLanguage, fileURL: URL) throws -> [Invocation] {
    let fileName = fileURL.lastPathComponent
    switch language {
    case .swift:
      let swift = try requireTool(candidates: ["swift"], language: language)
      return [Invocation(executable: swift, arguments: [fileName], isCheck: false)]

    case .python:
      let python = try requireTool(candidates: ["python3", "python"], language: language)
      return [Invocation(executable: python, arguments: [fileName], isCheck: false)]

    case .javascript:
      let node = try requireTool(candidates: ["node"], language: language)
      return [Invocation(executable: node, arguments: [fileName], isCheck: false)]

    case .typescript:
      var plan: [Invocation] = []
      if let tsc = findExecutable(candidates: ["tsc"]) {
        plan.append(Invocation(
          executable: tsc,
          arguments: ["--noEmit", "--skipLibCheck", "--target", "es2022", fileName],
          isCheck: true
        ))
      }
      let runners: [(name: String, arguments: [String])] = [
        ("tsx", [fileName]),
        ("deno", ["run", "--quiet", "--allow-all", fileName]),
        ("bun", ["run", fileName]),
        ("node", ["--experimental-strip-types", "--no-warnings", fileName]),
      ]
      guard let runner = runners.first(where: { findExecutable(candidates: [$0.name]) != nil }),
            let executable = findExecutable(candidates: [runner.name]) else {
        throw CodeRunnerError.toolNotFound(language: language, candidates: runners.map(\.name))
      }
      plan.append(Invocation(executable: executable, arguments: runner.arguments, isCheck: false))
      return plan
    }
  }

  private func requireTool(candidates: [String], language: CodeRunLanguage) throws -> URL {
    guard let url = findExecutable(candidates: candidates) else {
      throw CodeRunnerError.toolNotFound(language: language, candidates: candidates)
    }
    return url
  }

  private func findExecutable(candidates: [String]) -> URL? {
    for name in candidates {
      for directory in effectiveSearchPaths {
        let url = URL(fileURLWithPath: directory).appendingPathComponent(name)
        if FileManager.default.isExecutableFile(atPath: url.path) {
          return url
        }
      }
    }
    return nil
  }

  // MARK: - Process execution

  private actor TimeoutFlag {
    private(set) var didFire = false
    func mark() { didFire = true }
  }

  /// Accumulates pipe output from `readabilityHandler` callbacks. Callback-driven
  /// capture keeps the cooperative thread pool free — `FileHandle.bytes` would
  /// park a pool thread in a blocking read for the whole run.
  private final class OutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()
    private var truncated = false
    private let limit: Int

    init(limit: Int) {
      self.limit = limit
    }

    func append(_ chunk: Data) {
      lock.lock()
      defer { lock.unlock() }
      let remaining = limit - data.count
      if remaining > 0 {
        data.append(chunk.prefix(remaining))
      }
      if chunk.count > max(remaining, 0) {
        truncated = true
      }
    }

    var text: String {
      lock.lock()
      defer { lock.unlock() }
      let captured = String(decoding: data, as: UTF8.self)
      return truncated ? captured + "\n… [output truncated]" : captured
    }
  }

  private static func beginCapture(
    _ handle: FileHandle,
    limit: Int
  ) -> (buffer: OutputBuffer, finished: AsyncStream<Void>) {
    let buffer = OutputBuffer(limit: limit)
    let (finished, continuation) = AsyncStream.makeStream(of: Void.self)
    handle.readabilityHandler = { readHandle in
      let chunk = readHandle.availableData
      if chunk.isEmpty {
        readHandle.readabilityHandler = nil
        continuation.finish()
      } else {
        buffer.append(chunk)
      }
    }
    return (buffer, finished)
  }

  /// Waits for both pipes to hit EOF, bounded so a lingering grandchild that
  /// inherited the pipe can't stall the result after the process exited.
  private static func awaitEOF(_ streams: [AsyncStream<Void>], gracePeriod: Duration) async {
    let drain = Task {
      for stream in streams {
        for await _ in stream {}
      }
    }
    let cap = Task {
      try? await Task.sleep(for: gracePeriod)
      drain.cancel()
    }
    await drain.value
    cap.cancel()
  }

  private func execute(
    _ invocation: Invocation,
    language: CodeRunLanguage,
    workingDirectory: URL
  ) async throws -> CodeRunResult {
    let process = Process()
    process.executableURL = invocation.executable
    process.arguments = invocation.arguments
    process.currentDirectoryURL = workingDirectory

    var environment = ProcessInfo.processInfo.environment
    environment["PATH"] = effectiveSearchPaths.joined(separator: ":")
    environment["NO_COLOR"] = "1"
    environment["PYTHONUNBUFFERED"] = "1"
    process.environment = environment
    // EOF instead of a hang for programs that read stdin.
    process.standardInput = FileHandle.nullDevice

    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe

    let (exitEvents, exitContinuation) = AsyncStream.makeStream(of: Int32.self)
    process.terminationHandler = { finished in
      exitContinuation.yield(finished.terminationStatus)
      exitContinuation.finish()
    }

    let stdoutCapture = Self.beginCapture(stdoutPipe.fileHandleForReading, limit: maxOutputBytes)
    let stderrCapture = Self.beginCapture(stderrPipe.fileHandleForReading, limit: maxOutputBytes)

    let clock = ContinuousClock()
    let start = clock.now
    do {
      try process.run()
    } catch {
      stdoutPipe.fileHandleForReading.readabilityHandler = nil
      stderrPipe.fileHandleForReading.readabilityHandler = nil
      throw error
    }

    let timeoutFlag = TimeoutFlag()
    let watchdog = Task { [timeout] in
      try await Task.sleep(for: .seconds(timeout))
      await timeoutFlag.mark()
      Self.forceStop(process)
    }

    let exitCode: Int32? = await withTaskCancellationHandler {
      var iterator = exitEvents.makeAsyncIterator()
      return await iterator.next()
    } onCancel: {
      Self.forceStop(process)
    }
    watchdog.cancel()

    let elapsed = start.duration(to: clock.now)
    let duration = Double(elapsed.components.seconds)
      + Double(elapsed.components.attoseconds) * 1e-18

    await Self.awaitEOF(
      [stdoutCapture.finished, stderrCapture.finished],
      gracePeriod: .seconds(2)
    )

    try Task.checkCancellation()
    guard let exitCode else { throw CancellationError() }

    return CodeRunResult(
      language: language,
      commandLine: ([invocation.executable.lastPathComponent] + invocation.arguments)
        .joined(separator: " "),
      exitCode: exitCode,
      standardOutput: stdoutCapture.buffer.text,
      standardError: stderrCapture.buffer.text,
      duration: duration,
      didTimeOut: await timeoutFlag.didFire
    )
  }

  private static func forceStop(_ process: Process) {
    guard process.isRunning else { return }
    process.terminate()
    let pid = process.processIdentifier
    Task {
      try await Task.sleep(for: .milliseconds(500))
      if process.isRunning {
        kill(pid, SIGKILL)
      }
    }
  }

}
