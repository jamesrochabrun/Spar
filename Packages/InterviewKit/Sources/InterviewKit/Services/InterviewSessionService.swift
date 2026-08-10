//
//  InterviewSessionService.swift
//  InterviewKit
//

import Foundation
import Observation

/// Active-attempt lifecycle: begin, link chat session, hints, evaluation
/// transitions, abandon. Wired to ChatService in the app layer.
@Observable @MainActor
public final class InterviewSessionService {

  public private(set) var activeAttempt: InterviewAttempt?
  public private(set) var activeQuestion: Question?
  public private(set) var latestEvaluation: RubricEvaluation?
  public private(set) var latestNotes: [ImprovementNote] = []

  /// Per-rep progress for the active drill. Lives for the session: the run is
  /// a live coaching signal, and the attempt's evaluation is what persists.
  public private(set) var drillRun = DrillRun()

  /// Difficulty the candidate asked for when starting the run — the floor the
  /// ladder walks up and down from before any rep has been graded.
  private var requestedDifficulty: Difficulty = .medium

  /// Fires when an evaluation is persisted so the UI can switch to the report.
  public var onEvaluationCompleted: ((RubricEvaluation) -> Void)?

  private let storage: any InterviewStorageProtocol
  private let workspaceManager: any InterviewWorkspaceManaging

  public init(
    storage: any InterviewStorageProtocol,
    workspaceManager: any InterviewWorkspaceManaging = InterviewWorkspaceManager()
  ) {
    self.storage = storage
    self.workspaceManager = workspaceManager
  }

  // MARK: - Lifecycle

  @discardableResult
  public func beginAttempt(
    mode: SessionMode,
    question: Question? = nil,
    durationSeconds: Int? = nil,
    hintBudget: Int = 3,
    provider: String,
    requestedDifficulty: Difficulty = .medium
  ) async throws -> InterviewAttempt {
    await leaveActiveAttempt()

    let workspaceSlug = question?.title ?? mode.displayName
    let workspacePath = try? workspaceManager.createWorkspace(slug: workspaceSlug)

    let attempt = InterviewAttempt(
      questionId: question?.id,
      provider: provider,
      mode: mode,
      status: .inProgress,
      startedAt: Date(),
      plannedDurationSeconds: durationSeconds,
      hintBudget: hintBudget,
      workspacePath: workspacePath
    )

    try await storage.createAttempt(attempt)
    activeAttempt = attempt
    activeQuestion = question
    latestEvaluation = nil
    latestNotes = []
    drillRun = DrillRun()
    self.requestedDifficulty = requestedDifficulty
    return attempt
  }

  /// Records the verdict for the rep the agent just finished (buddy-rep fence).
  /// Drills only — other modes have a single graded attempt.
  public func recordDrillRep(_ rep: DrillRep) {
    guard activeAttempt?.mode == .drill else { return }
    drillRun.append(rep)
  }

  /// Difficulty the next rep should use, from the app's own ladder.
  public var suggestedNextDifficulty: Difficulty {
    drillRun.suggestedNextDifficulty(startingFrom: requestedDifficulty)
  }

  public func linkChatSession(_ chatSessionId: String) async {
    guard var attempt = activeAttempt, attempt.chatSessionId != chatSessionId else { return }
    attempt.chatSessionId = chatSessionId
    activeAttempt = attempt
    try? await storage.linkChatSession(attemptId: attempt.id, chatSessionId: chatSessionId)
  }

  /// The agent presented a question mid-session (captured from a buddy-question
  /// fence): attach it to the active attempt.
  public func attachQuestion(_ question: Question) async {
    guard var attempt = activeAttempt else { return }
    attempt.questionId = question.id
    activeAttempt = attempt
    activeQuestion = question
    try? await storage.updateAttempt(attempt)
  }

  public func recordHintUsed() async {
    guard var attempt = activeAttempt else { return }
    attempt.hintsUsed += 1
    activeAttempt = attempt
    try? await storage.updateAttempt(attempt)
  }

  /// Transition to awaiting_evaluation (timer expiry or "End & grade").
  public func requestEvaluation() async {
    guard var attempt = activeAttempt, attempt.status == .inProgress else { return }
    attempt.status = .awaitingEvaluation
    attempt.endedAt = Date()
    activeAttempt = attempt
    try? await storage.updateAttempt(attempt)
  }

  public func completeEvaluation(_ evaluation: RubricEvaluation, notes: [ImprovementNote]) async {
    guard var attempt = activeAttempt, evaluation.attemptId == attempt.id else { return }
    try? await storage.saveEvaluation(evaluation, notes: notes)
    attempt.status = .evaluated
    if attempt.endedAt == nil {
      attempt.endedAt = Date()
    }
    activeAttempt = attempt
    latestEvaluation = evaluation
    latestNotes = notes
    try? await storage.updateAttempt(attempt)
    onEvaluationCompleted?(evaluation)
  }

  public func abandon() async {
    await leaveActiveAttempt()
  }

  /// Leaves the visible attempt, abandoning unfinished work while preserving
  /// attempts that are already being graded or have completed.
  public func leaveActiveAttempt() async {
    if var attempt = activeAttempt, attempt.status == .inProgress {
      attempt.status = .abandoned
      attempt.endedAt = Date()
      try? await storage.updateAttempt(attempt)
    }

    clearActiveAttempt()
  }

  private func activate(_ attempt: InterviewAttempt?) async {
    guard let attempt else {
      clearActiveAttempt()
      return
    }

    activeAttempt = attempt
    if let questionId = attempt.questionId {
      activeQuestion = try? await storage.question(id: questionId)
    } else {
      activeQuestion = nil
    }
    latestEvaluation = try? await storage.evaluation(forAttemptId: attempt.id)
    latestNotes = (try? await storage.notes(forAttemptId: attempt.id)) ?? []
  }

  private func replaceActiveAttempt(with attempt: InterviewAttempt?) async {
    if activeAttempt?.id != attempt?.id {
      await leaveActiveAttempt()
    }

    await activate(attempt)
  }

  private func clearActiveAttemptState() {
    activeAttempt = nil
    activeQuestion = nil
    latestEvaluation = nil
    latestNotes = []
    drillRun = DrillRun()
  }

  /// Deletes the attempt linked to a chat session, including its managed
  /// workspace and dependent evaluation records.
  public func deleteAttempt(forChatSessionId chatSessionId: String) async throws {
    guard let attempt = try await storage.attempt(forChatSessionId: chatSessionId) else {
      return
    }

    if let workspacePath = attempt.workspacePath {
      try workspaceManager.deleteWorkspace(atPath: workspacePath)
    }
    try await storage.deleteAttempt(id: attempt.id)

    if activeAttempt?.id == attempt.id {
      clearActiveAttempt()
    }
  }

  // MARK: - Restore

  /// Sidebar restore: selecting a chat session re-activates its attempt.
  @discardableResult
  public func restoreAttempt(forChatSessionId chatSessionId: String) async -> InterviewAttempt? {
    let attempt = try? await storage.attempt(forChatSessionId: chatSessionId)
    await replaceActiveAttempt(with: attempt)
    return attempt
  }

  public func clearActiveAttempt() {
    clearActiveAttemptState()
  }

  // MARK: - Derived

  public var hintsRemaining: Int? {
    guard let attempt = activeAttempt else { return nil }
    return max(0, attempt.hintBudget - attempt.hintsUsed)
  }

  /// Deadline for a timed active attempt, nil when untimed.
  public var attemptDeadline: Date? {
    guard let attempt = activeAttempt,
          let duration = attempt.plannedDurationSeconds else { return nil }
    return attempt.startedAt.addingTimeInterval(TimeInterval(duration))
  }
}
