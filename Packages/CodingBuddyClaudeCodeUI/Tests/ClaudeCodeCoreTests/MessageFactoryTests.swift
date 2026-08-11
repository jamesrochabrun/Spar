//
//  MessageFactoryTests.swift
//  ClaudeCodeCoreTests
//

import XCTest
@testable import ClaudeCodeCore

final class MessageFactoryTests: XCTestCase {
  func testToolMessagesPreserveProviderToolUseID() {
    let toolUse = MessageFactory.toolUseMessage(
      toolName: "mcp__excalidraw__create_view",
      input: "elements: []",
      toolUseID: "toolu_123"
    )
    let toolResult = MessageFactory.toolResultMessage(
      content: .string(#"{"checkpointId":"abc"}"#),
      isError: false,
      toolUseID: "toolu_123"
    )

    XCTAssertEqual(toolUse.toolUseID, "toolu_123")
    XCTAssertEqual(toolResult.toolUseID, "toolu_123")
  }

  func testThinkingMessageUsesProviderContentWithoutAddingVisibleLabel() {
    let message = MessageFactory.thinkingMessage(content: "Evaluating files")

    XCTAssertEqual(message.role, .thinking)
    XCTAssertEqual(message.messageType, .thinking)
    XCTAssertEqual(message.content, "Evaluating files")
  }

  func testEmptyThinkingMessageStaysEmpty() {
    let message = MessageFactory.thinkingMessage(content: "")

    XCTAssertEqual(message.content, "")
  }
}
