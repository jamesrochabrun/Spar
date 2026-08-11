//
//  SystemDesignWhiteboardEmptyView.swift
//  CodingBuddyChat
//

import CodingBuddyKit
import SwiftUI

/// Transient placeholder before the shared MCP whiteboard exists. The session
/// kickoff asks Buddy to create the canvas in its first turn, so this normally
/// just shows setup progress; the manual create button is the fallback for
/// sessions where that didn't happen (e.g. restored older sessions).
public struct SystemDesignWhiteboardEmptyView: View {
  private let isCreatingWhiteboard: Bool
  private let canCreateWhiteboard: Bool
  private let onCreateWhiteboard: () -> Void

  @Environment(\.colorScheme) private var colorScheme

  public init(
    isCreatingWhiteboard: Bool,
    canCreateWhiteboard: Bool,
    onCreateWhiteboard: @escaping () -> Void
  ) {
    self.isCreatingWhiteboard = isCreatingWhiteboard
    self.canCreateWhiteboard = canCreateWhiteboard
    self.onCreateWhiteboard = onCreateWhiteboard
  }

  public var body: some View {
    ContentUnavailableView {
      Label("Shared whiteboard", systemImage: "rectangle.3.group")
    } description: {
      Text(
        "Buddy sets up an editable canvas at the start of the session — start diagramming as soon as it appears."
      )
    } actions: {
      VStack(spacing: 12) {
        if isCreatingWhiteboard {
          HStack(spacing: 8) {
            ProgressView()
              .controlSize(.small)
            Text("Buddy is setting up the whiteboard…")
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
      }
      .controlSize(.large)
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(EaselDesignSystem.Palette.canvas(for: colorScheme))
  }
}
