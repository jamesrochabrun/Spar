//
//  CapsuleInputView.swift
//  Spar
//

import CodingBuddyKit
import SwiftUI

struct CapsuleInputView: View {
  @Bindable var appState: AppState
  var onDismiss: () -> Void = {}
  @State private var isSendButtonPressed = false
  @FocusState private var isFocused: Bool
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    HStack(spacing: 12) {
      TextField("Ask \(AppBrand.name) anything", text: $appState.promptText)
        .textFieldStyle(.plain)
        .font(EaselDesignSystem.Typography.interface(size: 15))
        .foregroundStyle(.primary)
        .focused($isFocused)
        .onSubmit {
          appState.submitPrompt()
        }

      Button(action: handleSendButtonTap) {
        Image(systemName: "arrow.up")
          .font(EaselDesignSystem.Typography.interface(size: 13, weight: .bold))
          .foregroundStyle(sendIconColor)
          .frame(width: 32, height: 32)
          .background(sendButtonBackground, in: Circle())
          .scaleEffect(isSendButtonPressed ? 0.86 : 1)
      }
      .buttonStyle(.plain)
      .disabled(!canSubmit)
      .help("Send")
    }
    .padding(.leading, 20)
    .padding(.trailing, 12)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background {
      ZStack {
        GlassBackgroundView(material: .hudWindow)
        EaselDesignSystem.Palette.surface(for: colorScheme)
          .opacity(colorScheme == .dark ? 0.72 : 0.84)
      }
    }
    .clipShape(Capsule())
    .overlay {
      Capsule()
        .stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
    }
    .tint(EaselDesignSystem.Palette.accent)
    .onExitCommand(perform: onDismiss)
    .onAppear {
      isFocused = true
    }
  }

  private var canSubmit: Bool {
    !appState.promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private var sendButtonBackground: Color {
    canSubmit
      ? EaselDesignSystem.Palette.primaryAction(for: colorScheme)
      : EaselDesignSystem.Palette.subtleSurface(for: colorScheme)
  }

  private var sendIconColor: Color {
    canSubmit
      ? EaselDesignSystem.Palette.primaryActionForeground(for: colorScheme)
      : EaselDesignSystem.Palette.tertiaryText(for: colorScheme)
  }

  private func handleSendButtonTap() {
    appState.submitPrompt()

    guard !reduceMotion else { return }

    withAnimation(.spring(response: 0.16, dampingFraction: 0.62)) {
      isSendButtonPressed = true
    }

    Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(90))
      withAnimation(.spring(response: 0.24, dampingFraction: 0.58)) {
        isSendButtonPressed = false
      }
    }
  }
}
