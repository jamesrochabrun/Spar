import ClaudeCodeCore
import Foundation

extension ChatService: CodingBuddyVoiceSessionProviding {
  public var voiceSessionSnapshot: CodingBuddyVoiceSessionSnapshot? {
    guard isInitialized, let chatViewModel else { return nil }

    let question = interviewSession.activeQuestion
    let mode = currentMode ?? interviewSession.activeAttempt?.mode ?? .practice
    let name = question?.title
      ?? currentStudySpaceName
      ?? "\(mode.displayName) session"
    let status = chatViewModel.isLoading ? "Thinking" : "Ready"
    let recentTurns: [CodingBuddyVoiceTurn] = chatViewModel.messages.compactMap { message in
      guard message.isComplete, !message.content.isEmpty else { return nil }
      switch message.role {
      case .user:
        return CodingBuddyVoiceTurn(role: "user", text: message.content)
      case .assistant:
        return CodingBuddyVoiceTurn(role: "assistant", text: message.content)
      default:
        return nil
      }
    }

    return CodingBuddyVoiceSessionSnapshot(
      id: CodingBuddyVoiceHUDHost.targetID,
      name: name,
      mode: mode.displayName,
      provider: chatViewModel.activeProvider.displayName,
      status: status,
      questionTitle: question?.title,
      questionPrompt: question?.promptMarkdown,
      workspacePath: interviewSession.activeAttempt?.workspacePath
        ?? currentWorkingDirectory,
      recentTurns: Array(recentTurns.suffix(20))
    )
  }

  public var voiceLatestResponse: String? {
    chatViewModel?.messages.last(where: {
      $0.role == .assistant
        && $0.isComplete
        && !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    })?.content
  }

  public func deliverDictation(
    _ prompt: String,
    autoSubmit: Bool
  ) -> CodingBuddyVoicePromptOutcome {
    let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      return .unavailable("The voice transcript was empty.")
    }
    guard isInitialized, let chatViewModel else {
      return .unavailable("Open CodingBuddy and wait for the chat to initialize.")
    }

    if !autoSubmit {
      chatViewModel.requestInputDraft(trimmed)
      return .insertedIntoComposer
    }

    guard !chatViewModel.isLoading else { return .busy }
    sendMessage(trimmed)
    return .accepted
  }
}
