//
//  WorkspaceConsoleViewTests.swift
//  CodingBuddyChatTests
//

import Foundation
import InterviewKit
import Testing

@testable import CodingBuddyChat

@Suite("WorkspaceConsoleView")
struct WorkspaceConsoleViewTests {

  private func makeResult(
    exitCode: Int32 = 0,
    didTimeOut: Bool = false,
    duration: TimeInterval = 0.42
  ) -> CodeRunResult {
    CodeRunResult(
      language: .python,
      commandLine: "python3 solution.py",
      exitCode: exitCode,
      standardOutput: "",
      standardError: "",
      duration: duration,
      didTimeOut: didTimeOut
    )
  }

  @Test
  func statusIsEmptyBeforeFirstRun() {
    #expect(WorkspaceConsoleView.statusText(isRunning: false, result: nil, errorMessage: nil) == "")
  }

  @Test
  func statusShowsRunning() {
    #expect(WorkspaceConsoleView.statusText(isRunning: true, result: nil, errorMessage: nil) == "running…")
  }

  @Test
  func statusShowsExitCodeAndDuration() {
    let passed = WorkspaceConsoleView.statusText(
      isRunning: false, result: makeResult(exitCode: 0), errorMessage: nil
    )
    let failed = WorkspaceConsoleView.statusText(
      isRunning: false, result: makeResult(exitCode: 1), errorMessage: nil
    )
    #expect(passed == "exit 0 · 0.42s")
    #expect(failed == "exit 1 · 0.42s")
  }

  @Test
  func statusShowsTimeout() {
    let status = WorkspaceConsoleView.statusText(
      isRunning: false,
      result: makeResult(exitCode: 15, didTimeOut: true, duration: 30),
      errorMessage: nil
    )
    #expect(status == "timed out · 30.00s")
  }

  @Test
  func statusDistinguishesStoppedFromFailed() {
    let stopped = WorkspaceConsoleView.statusText(
      isRunning: false, result: nil, errorMessage: WorkspaceConsoleView.stoppedMessage
    )
    let failed = WorkspaceConsoleView.statusText(
      isRunning: false, result: nil, errorMessage: "No Python runtime found."
    )
    #expect(stopped == "stopped")
    #expect(failed == "failed")
  }
}
