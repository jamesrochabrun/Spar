public enum CodingBuddyVoicePromptOutcome: Equatable, Sendable {
  case accepted
  case insertedIntoComposer
  case busy
  case unavailable(String)
}
