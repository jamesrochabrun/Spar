import InterviewKit
import Testing

@testable import CodingBuddyChat

@Suite("System design whiteboard request policy")
struct SystemDesignWhiteboardRequestPolicyTests {
  @Test
  func allowsAnIdleInProgressSystemDesignSession() {
    #expect(SystemDesignWhiteboardRequestPolicy.canRequest(
      mode: .systemDesign,
      attemptStatus: .inProgress,
      isChatLoading: false,
      hasChatViewModel: true
    ))
  }

  @Test
  func rejectsRequestsThatCannotStart() {
    #expect(!SystemDesignWhiteboardRequestPolicy.canRequest(
      mode: .practice,
      attemptStatus: .inProgress,
      isChatLoading: false,
      hasChatViewModel: true
    ))
    #expect(!SystemDesignWhiteboardRequestPolicy.canRequest(
      mode: .systemDesign,
      attemptStatus: .evaluated,
      isChatLoading: false,
      hasChatViewModel: true
    ))
    #expect(!SystemDesignWhiteboardRequestPolicy.canRequest(
      mode: .systemDesign,
      attemptStatus: .inProgress,
      isChatLoading: true,
      hasChatViewModel: true
    ))
    #expect(!SystemDesignWhiteboardRequestPolicy.canRequest(
      mode: .systemDesign,
      attemptStatus: .inProgress,
      isChatLoading: false,
      hasChatViewModel: false
    ))
  }

  @Test
  func reviewRequiresLiveAttemptIdleChatAndACanvas() {
    #expect(SystemDesignWhiteboardRequestPolicy.canRequestReview(
      attemptStatus: .inProgress,
      isChatLoading: false,
      hasRenderItems: true
    ))
    #expect(!SystemDesignWhiteboardRequestPolicy.canRequestReview(
      attemptStatus: .inProgress,
      isChatLoading: false,
      hasRenderItems: false
    ))
    #expect(!SystemDesignWhiteboardRequestPolicy.canRequestReview(
      attemptStatus: .inProgress,
      isChatLoading: true,
      hasRenderItems: true
    ))
    #expect(!SystemDesignWhiteboardRequestPolicy.canRequestReview(
      attemptStatus: .evaluated,
      isChatLoading: false,
      hasRenderItems: true
    ))
  }
}
