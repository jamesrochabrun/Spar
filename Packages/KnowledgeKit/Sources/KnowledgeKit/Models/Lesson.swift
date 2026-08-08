import Foundation

/// One agent-led turn of a study-plan item, parsed from a `buddy-lesson` fence.
///
/// A lesson is the unit the Lesson surface renders: exactly one scenario, one
/// cited source, and one task, plus the feedback on the previous response when
/// this is not the item's opening turn. It is deliberately not persisted — the
/// transcript is the record, and the app owns only checklist completion.
public struct Lesson: Identifiable, Equatable, Sendable {

  /// The single place the learner is told to look. `locator` is a human-facing
  /// range or symbol name ("lines 112-160", "makeSessionContext(mode:)");
  /// `chunkID` is the buddy-evidence citation id, present only when the agent
  /// grounded the task in a retrieved passage.
  public struct SourceReference: Equatable, Sendable {
    public var path: String
    public var locator: String
    public var chunkID: String?

    public init(path: String, locator: String = "", chunkID: String? = nil) {
      self.path = path
      self.locator = locator
      self.chunkID = chunkID
    }

    public var displayName: String {
      let fileName = (path as NSString).lastPathComponent
      guard !locator.isEmpty else { return fileName }
      return "\(fileName) · \(locator)"
    }
  }

  public var id: String { "\(itemID)#\(step)" }

  /// Stable study-plan item id this lesson teaches. Empty when the agent
  /// omitted it and the app could not resolve the requested item.
  public var itemID: String
  public var itemTitle: String
  public var step: Int
  public var totalSteps: Int

  /// One sentence naming what the learner will be able to do afterwards.
  public var outcome: String
  /// Short context for why the outcome matters — never the task's answer.
  public var whyMarkdown: String
  public var source: SourceReference?
  /// The concrete repository situation the learner reasons about.
  public var scenarioMarkdown: String
  /// 2-3 things to look at in the cited source.
  public var inspectSteps: [String]
  /// Response shape ("Note: ___ / Prediction: ___ because ___"). A guide, not
  /// a required format — the surface seeds the editor with it and says so.
  public var replyScaffold: String

  /// Response to what the learner just said. Absent on an item's first turn.
  public var feedbackMarkdown: String?
  /// What the observation teaches about this repository. Absent on turn one.
  public var teachesMarkdown: String?

  /// The agent's signal that the item's objective is met. Advisory only — the
  /// learner still owns the checkmark.
  public var isItemComplete: Bool

  public init(
    itemID: String = "",
    itemTitle: String = "",
    step: Int = 1,
    totalSteps: Int = 1,
    outcome: String = "",
    whyMarkdown: String = "",
    source: SourceReference? = nil,
    scenarioMarkdown: String = "",
    inspectSteps: [String] = [],
    replyScaffold: String = "",
    feedbackMarkdown: String? = nil,
    teachesMarkdown: String? = nil,
    isItemComplete: Bool = false
  ) {
    self.itemID = itemID
    self.itemTitle = itemTitle
    self.step = step
    self.totalSteps = totalSteps
    self.outcome = outcome
    self.whyMarkdown = whyMarkdown
    self.source = source
    self.scenarioMarkdown = scenarioMarkdown
    self.inspectSteps = inspectSteps
    self.replyScaffold = replyScaffold
    self.feedbackMarkdown = feedbackMarkdown
    self.teachesMarkdown = teachesMarkdown
    self.isItemComplete = isItemComplete
  }

  /// True on an item's opening turn — nothing has been responded to yet.
  public var isOpeningTurn: Bool {
    feedbackMarkdown == nil && teachesMarkdown == nil
  }

  /// True when the agent wrapped up without handing back a new task, so the
  /// surface offers "mark complete" instead of a response editor.
  public var isClosingTurn: Bool {
    scenarioMarkdown.isEmpty && inspectSteps.isEmpty
  }
}
