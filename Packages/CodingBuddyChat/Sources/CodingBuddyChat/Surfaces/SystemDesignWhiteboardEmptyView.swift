//
//  SystemDesignWhiteboardEmptyView.swift
//  CodingBuddyChat
//

import CodingBuddyKit
import SwiftUI

/// Offers the two actions that are actually available before a shared MCP
/// whiteboard exists: return focus to chat or create the canvas.
public struct SystemDesignWhiteboardEmptyView: View {
  private let isCreatingWhiteboard: Bool
  private let canCreateWhiteboard: Bool
  private let onContinueInChat: () -> Void
  private let onCreateWhiteboard: () -> Void

  @Environment(\.colorScheme) private var colorScheme

  public init(
    isCreatingWhiteboard: Bool,
    canCreateWhiteboard: Bool,
    onContinueInChat: @escaping () -> Void,
    onCreateWhiteboard: @escaping () -> Void
  ) {
    self.isCreatingWhiteboard = isCreatingWhiteboard
    self.canCreateWhiteboard = canCreateWhiteboard
    self.onContinueInChat = onContinueInChat
    self.onCreateWhiteboard = onCreateWhiteboard
  }

  public var body: some View {
    ContentUnavailableView {
      Label("Create a shared whiteboard", systemImage: "rectangle.3.group")
    } description: {
      Text(
        "Clarify the problem in chat, then create an editable canvas whenever you are ready to sketch."
      )
    } actions: {
      VStack(spacing: 12) {
        if isCreatingWhiteboard {
          HStack(spacing: 8) {
            ProgressView()
              .controlSize(.small)
            Text("Buddy is creating the whiteboard…")
          }
          .foregroundStyle(.secondary)
          .accessibilityElement(children: .combine)
        } else {
          Button(
            "Create Whiteboard",
            systemImage: "rectangle.3.group",
            action: onCreateWhiteboard
          )
          .buttonStyle(.borderedProminent)
          .disabled(!canCreateWhiteboard)

          if !canCreateWhiteboard {
            Text("Wait for Buddy to finish responding before creating the canvas.")
              .font(.callout)
              .foregroundStyle(.secondary)
          }
        }

        Button(
          "Focus Chat",
          systemImage: "message",
          action: onContinueInChat
        )
        .buttonStyle(.bordered)
      }
      .controlSize(.large)
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(EaselDesignSystem.Palette.canvas(for: colorScheme))
  }
}
