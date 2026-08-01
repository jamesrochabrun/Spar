//
//  WorkspaceConsoleView.swift
//  CodingBuddyChat
//
//  Output console for the workspace surface: shows the command, captured
//  stdout/stderr, and the exit status of the last Run.
//

import CodingBuddyKit
import InterviewKit
import SwiftUI

struct WorkspaceConsoleView: View {
  let isRunning: Bool
  let result: CodeRunResult?
  let errorMessage: String?
  let onStop: () -> Void
  let onClose: () -> Void

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    VStack(spacing: 0) {
      header

      Rectangle()
        .fill(EaselDesignSystem.Palette.border(for: colorScheme))
        .frame(height: 1)

      output
    }
    .background(EaselDesignSystem.Palette.surface(for: colorScheme))
  }

  private var header: some View {
    HStack(spacing: 8) {
      Image(systemName: "terminal")
        .font(.system(size: 10))
        .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))

      Text("Console")
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))

      if isRunning {
        ProgressView()
          .controlSize(.mini)
      }

      Spacer()

      Text(Self.statusText(isRunning: isRunning, result: result, errorMessage: errorMessage))
        .font(.system(size: 11, design: .monospaced))
        .foregroundStyle(statusColor)
        .lineLimit(1)

      if isRunning {
        Button("Stop", systemImage: "stop.fill", action: onStop)
          .buttonStyle(.plain)
          .labelStyle(.titleAndIcon)
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(EaselDesignSystem.Palette.danger)
      }

      Button {
        onClose()
      } label: {
        Image(systemName: "xmark")
          .font(.system(size: 9, weight: .semibold))
      }
      .buttonStyle(.plain)
      .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
      .help("Close console")
      .accessibilityLabel("Close console")
    }
    .padding(.horizontal, 14)
    .frame(height: 28)
  }

  private var output: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 2) {
        if let result {
          Text("$ \(result.commandLine)")
            .foregroundStyle(EaselDesignSystem.Palette.tertiaryText(for: colorScheme))

          if !result.standardOutput.isEmpty {
            Text(result.standardOutput)
              .foregroundStyle(.primary)
          }
          if !result.standardError.isEmpty {
            Text(result.standardError)
              .foregroundStyle(EaselDesignSystem.Palette.danger)
          }
          if result.standardOutput.isEmpty && result.standardError.isEmpty {
            Text("(no output)")
              .foregroundStyle(EaselDesignSystem.Palette.tertiaryText(for: colorScheme))
          }
        } else if let errorMessage {
          Text(errorMessage)
            .foregroundStyle(EaselDesignSystem.Palette.danger)
        } else if isRunning {
          Text("Running…")
            .foregroundStyle(EaselDesignSystem.Palette.tertiaryText(for: colorScheme))
        }
      }
      .font(.system(size: 12, design: .monospaced))
      .textSelection(.enabled)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 14)
      .padding(.vertical, 8)
    }
  }

  private var statusColor: Color {
    if errorMessage != nil {
      return EaselDesignSystem.Palette.danger
    }
    if isRunning {
      return EaselDesignSystem.Palette.running
    }
    guard let result else {
      return EaselDesignSystem.Palette.tertiaryText(for: colorScheme)
    }
    if result.didTimeOut {
      return EaselDesignSystem.Palette.warning
    }
    return result.succeeded ? EaselDesignSystem.Palette.success : EaselDesignSystem.Palette.danger
  }

  static let stoppedMessage = "Run stopped."

  /// Pure so tests can pin the status wording for every run state.
  static func statusText(isRunning: Bool, result: CodeRunResult?, errorMessage: String?) -> String {
    if let errorMessage {
      return errorMessage == stoppedMessage ? "stopped" : "failed"
    }
    if isRunning {
      return "running…"
    }
    guard let result else {
      return ""
    }
    let seconds = String(format: "%.2fs", result.duration)
    if result.didTimeOut {
      return "timed out · \(seconds)"
    }
    return "exit \(result.exitCode) · \(seconds)"
  }
}
