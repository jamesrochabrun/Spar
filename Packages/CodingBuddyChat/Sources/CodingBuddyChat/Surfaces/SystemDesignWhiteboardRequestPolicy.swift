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
}
