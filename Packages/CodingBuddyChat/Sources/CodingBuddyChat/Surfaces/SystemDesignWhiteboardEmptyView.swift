//
//  SystemDesignWhiteboardEmptyView.swift
//  CodingBuddyChat
//

import CodingBuddyKit
import SwiftUI

/// Guides the candidate through the requirements phase before a shared MCP
/// whiteboard exists.
public struct SystemDesignWhiteboardEmptyView: View {
  private static let phases = [
    "Requirements",
    "Estimates",
    "Architecture",
    "Deep Dive",
    "Review",
  ]

  private let isCreatingWhiteboard: Bool
  private let onContinueInChat: () -> Void
  private let onCreateWhiteboard: () -> Void

  @Environment(\.colorScheme) private var colorScheme

  public init(
    isCreatingWhiteboard: Bool,
    onContinueInChat: @escaping () -> Void,
    onCreateWhiteboard: @escaping () -> Void
  ) {
    self.isCreatingWhiteboard = isCreatingWhiteboard
    self.onContinueInChat = onContinueInChat
    self.onCreateWhiteboard = onCreateWhiteboard
  }

  public var body: some View {
    VStack(spacing: 24) {
      HStack(spacing: 8) {
        ForEach(Array(Self.phases.enumerated()), id: \.offset) { index, phase in
          Label(
            phase,
            systemImage: index == 0 ? "\(index + 1).circle.fill" : "\(index + 1).circle"
          )
          .foregroundStyle(index == 0 ? Color.primary : Color.secondary)

          if index < Self.phases.count - 1 {
            Image(systemName: "chevron.right")
              .foregroundStyle(.tertiary)
              .accessibilityHidden(true)
          }
        }
      }
      .font(.caption)
      .accessibilityElement(children: .combine)
      .accessibilityLabel("Current phase: Requirements. Next: Estimates, Architecture, Deep Dive, Review.")

      ContentUnavailableView {
        Label("Start with requirements", systemImage: "list.clipboard")
      } description: {
        Text(
          "Ask clarifying questions in chat about users, scale, consistency, offline behavior, and constraints. Create the canvas when you are ready to sketch the architecture."
        )
      } actions: {
        HStack {
          Button(
            "Continue in Chat",
            systemImage: "message",
            action: onContinueInChat
          )
          .buttonStyle(.borderedProminent)

          Button(action: onCreateWhiteboard) {
            Label(
              isCreatingWhiteboard ? "Creating Whiteboard…" : "Create Whiteboard",
              systemImage: isCreatingWhiteboard ? "hourglass" : "rectangle.3.group"
            )
          }
          .buttonStyle(.bordered)
          .disabled(isCreatingWhiteboard)
        }
        .controlSize(.large)
      }
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(EaselDesignSystem.Palette.canvas(for: colorScheme))
  }
}
