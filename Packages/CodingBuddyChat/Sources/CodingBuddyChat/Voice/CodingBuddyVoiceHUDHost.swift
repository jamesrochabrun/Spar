import AgentHubVoice
import Foundation

@MainActor
final class CodingBuddyVoiceHUDHost: VoiceHUDHost {
  static let targetID = "codingbuddy.active-session"

  private weak var session: (any CodingBuddyVoiceSessionProviding)?
  private let keyProvider: any OpenAIKeyProviding
  private let toolCatalog: CodingBuddyVoiceToolCatalog
  private let defaults: UserDefaults

  init(
    session: any CodingBuddyVoiceSessionProviding,
    engine: RealtimeVoiceEngine,
    keyProvider: any OpenAIKeyProviding,
    screenCapture: any VoiceScreenCapturing = VoiceScreenCaptureService(),
    defaults: UserDefaults = .standard
  ) {
    self.session = session
    self.keyProvider = keyProvider
    self.defaults = defaults
    toolCatalog = CodingBuddyVoiceToolCatalog(
      session: session,
      engine: engine,
      screenCapture: screenCapture,
      defaults: defaults
    )
  }

  var targets: [VoiceHUDTarget] {
    guard let snapshot = session?.voiceSessionSnapshot else { return [] }
    return [Self.target(from: snapshot)]
  }

  func resolveTarget(manualId: String?) -> VoiceHUDTarget? {
    guard manualId == nil || manualId == Self.targetID,
          let snapshot = session?.voiceSessionSnapshot else {
      return nil
    }
    return Self.target(from: snapshot)
  }

  func makeToolRegistry() -> VoiceToolRegistry {
    VoiceToolRegistry(tools: toolCatalog.makeTools())
  }

  func makeSessionContext() -> String? {
    CodingBuddyVoiceSessionContextBuilder.make(
      snapshot: session?.voiceSessionSnapshot
    )
  }

  func makeRealtimeInstructions() -> String? {
    """
    You are a read-only side buddy for CodingBuddy's active interview-prep
    session. The parent chat agent may use Claude, Codex, or a Local/API
    provider. Never claim to be that agent and never send messages to it.

    Help the user understand the current problem, clarify concepts, brainstorm,
    reason through tradeoffs, and reflect on progress independently. Use
    list_sessions, get_session_status, read_session_history, and
    read_session_response to refresh context before relying on session-specific
    facts. The main chat transcript is read-only in realtime mode: do not create
    user turns, request work from the parent agent, or imply that you did.

    Use list_workspace_files and read_workspace_file to inspect the active
    attempt workspace without changing it. If the user asks about their screen,
    diagram, or visible app state, call capture_screen. The captured image is
    attached directly to this realtime conversation, so inspect it yourself and
    answer from what you can actually see. Never write, edit, or delete files.
    """
  }

  func resolveAPIKey() async throws -> String? {
    try await keyProvider.resolve()?.key
  }

  func deliverDictation(
    _ transcript: String,
    to targetId: String
  ) -> VoiceDictationOutcome {
    guard targetId == Self.targetID, let session else {
      return .failed("The active chat session is no longer available.")
    }

    let autoSubmit = defaults.bool(
      forKey: CodingBuddyVoiceDefaults.autoSubmitDictation
    )
    switch session.deliverDictation(transcript, autoSubmit: autoSubmit) {
    case .accepted, .insertedIntoComposer:
      return .delivered
    case .busy:
      return .failed("Wait for the current chat response before dictating again.")
    case .unavailable(let message):
      return .failed(message)
    }
  }

  private static func target(
    from snapshot: CodingBuddyVoiceSessionSnapshot
  ) -> VoiceHUDTarget {
    VoiceHUDTarget(
      id: targetID,
      name: snapshot.name,
      detail: "\(snapshot.provider) · \(snapshot.mode)"
    )
  }
}
