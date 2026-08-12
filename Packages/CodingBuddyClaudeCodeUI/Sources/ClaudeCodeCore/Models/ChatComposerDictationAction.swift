public struct ChatComposerDictationAction {
  public enum State: Equatable, Sendable {
    case idle
    case recording
    case transcribing
    case failed(String)
  }

  public let state: State
  public let isEnabled: Bool
  public let action: @MainActor () -> Void

  public init(
    state: State,
    isEnabled: Bool,
    action: @escaping @MainActor () -> Void
  ) {
    self.state = state
    self.isEnabled = isEnabled
    self.action = action
  }
}
