import Foundation
import XCTest

final class ChatInputViewSourceTests: XCTestCase {

  func testTextEditorUsesReadableInputTint() throws {
    let source = try sourceContents("Sources/ClaudeCodeCore/UI/ChatInputView.swift")

    XCTAssertTrue(source.contains(".tint(CodingBuddyChatRuntimeStyle.inputTint(for: colorScheme))"))
  }

  func testPermissionModePickerIsHiddenForEmbeddedChat() throws {
    let source = try sourceContents("Sources/ClaudeCodeCore/UI/ChatInputView.swift")

    XCTAssertTrue(source.contains("if viewModel.activeProvider == .codex"))
    XCTAssertTrue(source.contains("ClaudeModelBadge(modelIdentifier: globalPreferences.claudeModel)"))
    XCTAssertFalse(source.contains("if viewModel.activeProvider != .codex"))
    XCTAssertFalse(source.contains("PermissionModeButton(mode: $viewModel.permissionMode)"))
  }

  func testPermissionModeShortcutIsDisabledForEmbeddedChat() throws {
    let source = try sourceContents("Sources/ClaudeCodeCore/UI/ChatScreen.swift")

    XCTAssertFalse(source.contains("viewModel.permissionMode = newMode"))
  }

  func testExternalFocusRequestReachesChatInput() throws {
    let screenSource = try sourceContents("Sources/ClaudeCodeCore/UI/ChatScreen.swift")
    let inputSource = try sourceContents("Sources/ClaudeCodeCore/UI/ChatInputView.swift")

    XCTAssertTrue(screenSource.contains("triggerInputFocus: Binding<Bool>"))
    XCTAssertTrue(screenSource.contains("triggerFocus: $triggerInputFocus"))
    XCTAssertTrue(inputSource.contains("triggerFocus = false"))
  }

  func testComposerActionsUseCircularContainers() throws {
    let inputSource = try sourceContents("Sources/ClaudeCodeCore/UI/ChatInputView.swift")
    let dictationSource = try sourceContents(
      "Sources/ClaudeCodeCore/UI/ChatComposerDictationButton.swift"
    )

    XCTAssertTrue(inputSource.contains("in: Circle()"))
    XCTAssertTrue(dictationSource.contains(".background(backgroundStyle, in: Circle())"))
    XCTAssertTrue(inputSource.contains(".stroke(CodingBuddyChatRuntimeStyle.border"))
    XCTAssertTrue(dictationSource.contains(".stroke(borderStyle"))
  }

  func testTranscriptionUsesProgressInsteadOfWaveform() throws {
    let source = try sourceContents(
      "Sources/ClaudeCodeCore/UI/ChatComposerDictationButton.swift"
    )

    XCTAssertTrue(source.contains("ProgressView()"))
    XCTAssertFalse(source.contains("\"waveform\""))
  }

  func testVoiceCoachUsesAMagicalComposerOrb() throws {
    let inputSource = try sourceContents("Sources/ClaudeCodeCore/UI/ChatInputView.swift")
    let controlSource = try sourceContents(
      "Sources/ClaudeCodeCore/UI/ChatComposerVoiceCoachControl.swift"
    )

    XCTAssertTrue(inputSource.contains("ChatComposerVoiceCoachControl"))
    XCTAssertTrue(controlSource.contains("LinearGradient("))
    XCTAssertTrue(controlSource.contains("Image(systemName: \"sparkle\")"))
    XCTAssertTrue(controlSource.contains("accessibilityReduceMotion"))
    XCTAssertTrue(controlSource.contains("configuration.muteAction"))
    XCTAssertTrue(controlSource.contains("configuration.endAction"))
  }

  func testDictationIsHiddenWhileVoiceCoachIsActive() throws {
    let source = try sourceContents("Sources/ClaudeCodeCore/UI/ChatInputView.swift")

    XCTAssertTrue(
      source.contains(
        "if let dictationAction, voiceCoachAction?.state.isActive != true"
      )
    )
    XCTAssertTrue(
      source.contains("value: voiceCoachAction?.state.isActive == true")
    )
    XCTAssertTrue(source.contains("accessibilityReduceMotion"))
  }

  private func sourceContents(_ relativePath: String) throws -> String {
    let testsDirectory = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let packageDirectory = testsDirectory.deletingLastPathComponent()
    return try String(
      contentsOf: packageDirectory.appendingPathComponent(relativePath),
      encoding: .utf8
    )
  }
}
