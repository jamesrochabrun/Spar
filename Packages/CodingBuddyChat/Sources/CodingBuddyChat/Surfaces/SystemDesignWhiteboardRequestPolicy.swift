import InterviewKit

enum SystemDesignWhiteboardRequestPolicy {
  static func canRequest(
    mode: SessionMode?,
    attemptStatus: InterviewAttempt.Status?,
    isChatLoading: Bool,
    hasChatViewModel: Bool
  ) -> Bool {
    mode == .systemDesign &&
      attemptStatus == .inProgress &&
      !isChatLoading &&
      hasChatViewModel
  }

  /// The "review my whiteboard" action: meaningful in any mode once a shared
  /// canvas exists (the agent created one), the attempt is live, and the agent
  /// is idle. User edits sync back under the same checkpoint id, so the agent
  /// can re-read the canvas at any time.
  static func canRequestReview(
    attemptStatus: InterviewAttempt.Status?,
    isChatLoading: Bool,
    hasRenderItems: Bool
  ) -> Bool {
    attemptStatus == .inProgress &&
      !isChatLoading &&
      hasRenderItems
  }
}
