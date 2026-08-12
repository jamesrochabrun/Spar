@MainActor
public protocol CodingBuddyVoiceSessionProviding: AnyObject {
  var voiceSessionSnapshot: CodingBuddyVoiceSessionSnapshot? { get }
  var voiceLatestResponse: String? { get }

  func deliverDictation(
    _ prompt: String,
    autoSubmit: Bool
  ) -> CodingBuddyVoicePromptOutcome
}
