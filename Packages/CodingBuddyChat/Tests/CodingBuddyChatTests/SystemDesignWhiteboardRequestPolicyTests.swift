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
}
