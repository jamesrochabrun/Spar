//
//  CodeRunnerServiceTests.swift
//  InterviewKitTests
//

import Foundation
import Testing
@testable import InterviewKit

@Suite("CodeRunLanguage")
struct CodeRunLanguageTests {

  @Test
  func detectsSupportedExtensions() {
    #expect(CodeRunLanguage.detect(fileExtension: "swift") == .swift)
    #expect(CodeRunLanguage.detect(fileExtension: "py") == .python)
    #expect(CodeRunLanguage.detect(fileExtension: "js") == .javascript)
    #expect(CodeRunLanguage.detect(fileExtension: "mjs") == .javascript)
    #expect(CodeRunLanguage.detect(fileExtension: "cjs") == .javascript)
    #expect(CodeRunLanguage.detect(fileExtension: "ts") == .typescript)
    #expect(CodeRunLanguage.detect(fileExtension: "mts") == .typescript)
    #expect(CodeRunLanguage.detect(fileExtension: "SWIFT") == .swift)
  }

  @Test
  func rejectsUnsupportedExtensions() {
    #expect(CodeRunLanguage.detect(fileExtension: "rb") == nil)
    #expect(CodeRunLanguage.detect(fileExtension: "kt") == nil)
    #expect(CodeRunLanguage.detect(fileExtension: "") == nil)
  }
}

@Suite("ProcessCodeRunner", .timeLimit(.minutes(2)))
struct ProcessCodeRunnerTests {

  private func makeWorkspace() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("code-runner-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }

  private func write(_ source: String, named fileName: String, in workspace: URL) throws -> URL {
    let url = workspace.appendingPathComponent(fileName)
    try source.write(to: url, atomically: true, encoding: .utf8)
    return url
  }

  /// Runs the file, treating a missing toolchain on this machine as a skip.
  private func runIfToolAvailable(
    _ runner: ProcessCodeRunner,
    _ fileURL: URL
  ) async throws -> CodeRunResult? {
    do {
      return try await runner.run(fileURL: fileURL)
    } catch let error as CodeRunnerError {
      guard case .toolNotFound = error else { throw error }
      return nil
    }
  }

  @Test
  func throwsForUnsupportedFileType() async throws {
    let workspace = try makeWorkspace()
    let file = try write("puts 'hi'", named: "solution.rb", in: workspace)

    await #expect(throws: CodeRunnerError.unsupportedFileType(fileExtension: "rb")) {
      try await ProcessCodeRunner().run(fileURL: file)
    }
  }

  @Test
  func languageForFileExtensionUsesDetection() {
    let runner = ProcessCodeRunner()
    #expect(runner.language(forFileExtension: "py") == .python)
    #expect(runner.language(forFileExtension: "rb") == nil)
  }

  @Test
  func nvmNodeBinPathsSortNewestFirst() throws {
    let home = try makeWorkspace()
    let versions = home.appendingPathComponent(".nvm/versions/node", isDirectory: true)
    for version in ["v18.19.0", "v22.4.0", "v22.16.0", "not-a-version"] {
      try FileManager.default.createDirectory(
        at: versions.appendingPathComponent(version),
        withIntermediateDirectories: true
      )
    }

    let paths = ProcessCodeRunner.nvmNodeBinPaths(home: home.path)
    #expect(paths == [
      "\(home.path)/.nvm/versions/node/v22.16.0/bin",
      "\(home.path)/.nvm/versions/node/v22.4.0/bin",
      "\(home.path)/.nvm/versions/node/v18.19.0/bin",
    ])
  }

  @Test
  func nvmNodeBinPathsEmptyWithoutInstall() throws {
    let home = try makeWorkspace()
    #expect(ProcessCodeRunner.nvmNodeBinPaths(home: home.path).isEmpty)
  }

  @Test
  func runsPython() async throws {
    let workspace = try makeWorkspace()
    let file = try write("print(21 * 2)", named: "solution.py", in: workspace)

    guard let result = try await runIfToolAvailable(ProcessCodeRunner(), file) else { return }
    #expect(result.succeeded)
    #expect(result.standardOutput.contains("42"))
    #expect(result.language == .python)
    #expect(result.didTimeOut == false)
  }

  @Test
  func reportsPythonFailure() async throws {
    let workspace = try makeWorkspace()
    let file = try write("raise ValueError('boom')", named: "solution.py", in: workspace)

    guard let result = try await runIfToolAvailable(ProcessCodeRunner(), file) else { return }
    #expect(!result.succeeded)
    #expect(result.exitCode != 0)
    #expect(result.standardError.contains("boom"))
  }

  @Test
  func runsJavaScript() async throws {
    let workspace = try makeWorkspace()
    let file = try write("console.log('js-ok')", named: "solution.js", in: workspace)

    guard let result = try await runIfToolAvailable(ProcessCodeRunner(), file) else { return }
    #expect(result.succeeded)
    #expect(result.standardOutput.contains("js-ok"))
  }

  @Test
  func runsSwift() async throws {
    let workspace = try makeWorkspace()
    let file = try write("print(\"swift-ok\")", named: "solution.swift", in: workspace)

    guard let result = try await runIfToolAvailable(ProcessCodeRunner(), file) else { return }
    #expect(result.succeeded)
    #expect(result.standardOutput.contains("swift-ok"))
  }

  @Test
  func reportsSwiftCompileError() async throws {
    let workspace = try makeWorkspace()
    let file = try write("let x: Int = \"not an int\"", named: "solution.swift", in: workspace)

    guard let result = try await runIfToolAvailable(ProcessCodeRunner(), file) else { return }
    #expect(!result.succeeded)
    #expect(result.standardError.contains("error"))
  }

  @Test
  func runsTypeScript() async throws {
    let workspace = try makeWorkspace()
    let file = try write(
      "const answer: number = 21 * 2\nconsole.log(`ts-${answer}`)",
      named: "solution.ts",
      in: workspace
    )

    guard let result = try await runIfToolAvailable(ProcessCodeRunner(), file) else { return }
    #expect(result.succeeded)
    #expect(result.standardOutput.contains("ts-42"))
  }

  @Test
  func timesOutRunawayProcess() async throws {
    let workspace = try makeWorkspace()
    let file = try write("while True:\n    pass", named: "solution.py", in: workspace)
    let runner = ProcessCodeRunner(timeout: 1)

    guard let result = try await runIfToolAvailable(runner, file) else { return }
    #expect(result.didTimeOut)
    #expect(!result.succeeded)
  }

  @Test
  func truncatesOversizedOutput() async throws {
    let workspace = try makeWorkspace()
    let file = try write("print('x' * 100_000)", named: "solution.py", in: workspace)
    let runner = ProcessCodeRunner(maxOutputBytes: 1_000)

    guard let result = try await runIfToolAvailable(runner, file) else { return }
    #expect(result.standardOutput.contains("[output truncated]"))
    #expect(result.standardOutput.count < 2_000)
  }

  @Test
  func cancellingTaskStopsProcess() async throws {
    let workspace = try makeWorkspace()
    let file = try write("import time\ntime.sleep(60)", named: "solution.py", in: workspace)
    let runner = ProcessCodeRunner(timeout: 120)

    let task = Task { try await runner.run(fileURL: file) }
    try await Task.sleep(for: .milliseconds(500))
    task.cancel()

    do {
      let result = try await task.value
      // If python3 is missing this may throw toolNotFound before cancellation.
      #expect(!result.succeeded)
    } catch is CancellationError {
      // Expected path.
    } catch let error as CodeRunnerError {
      guard case .toolNotFound = error else { throw error }
    }
  }
}
