//
//  NewSessionSheet.swift
//  CodingBuddyChat
//

import ClaudeCodeCore
import CodingBuddyKit
import InterviewKit
import KnowledgeKit
import SwiftUI
import UniformTypeIdentifiers

/// "+" flow: mode, topic multi-select, difficulty, duration preset, hint
/// budget, provider, and optional retry-from-bank question.
public struct NewSessionSheet: View {

  private let topics: [Topic]
  private let bankQuestions: [Question]
  private let defaultProvider: ChatProvider
  private let specialization: InterviewSpecialization
  private let isModeSelectionLocked: Bool
  @Bindable private var knowledgeLibrary: KnowledgeLibraryService
  private let onStart: (ChatService.NewSessionRequest) -> Void
  private let onCancel: () -> Void

  @State private var mode: SessionMode
  @State private var selectedTopicIds: Set<String> = []
  @State private var difficulty: Difficulty = .medium
  @State private var durationMinutes: Int
  @State private var isTimed: Bool
  @State private var hintBudget = 3
  @State private var provider: ChatProvider
  @State private var selectedBankQuestionId: String?
  @State private var selectedStudySpaceID: String?
  @State private var knowledgeActivity: KnowledgeActivity
  @State private var sourceAccess: KnowledgeSourceAccess = .openBook
  @State private var isRepositoryImporterPresented = false
  @Environment(\.colorScheme) private var colorScheme

  private static let durationPresets = [20, 35, 45, 60]

  public init(
    initialMode: SessionMode = .mockInterview,
    topics: [Topic],
    bankQuestions: [Question],
    defaultProvider: ChatProvider,
    specialization: InterviewSpecialization = .default,
    isModeSelectionLocked: Bool = false,
    knowledgeLibrary: KnowledgeLibraryService,
    onStart: @escaping (ChatService.NewSessionRequest) -> Void,
    onCancel: @escaping () -> Void
  ) {
    self.topics = topics
    self.bankQuestions = bankQuestions
    self.defaultProvider = defaultProvider
    self.specialization = specialization
    self.isModeSelectionLocked = isModeSelectionLocked
    self.knowledgeLibrary = knowledgeLibrary
    self.onStart = onStart
    self.onCancel = onCancel
    self._mode = State(initialValue: initialMode)
    self._isTimed = State(initialValue: initialMode.isTimedByDefault)
    self._durationMinutes = State(initialValue: initialMode == .drill ? 20 : 35)
    self._provider = State(initialValue: defaultProvider)
    self._knowledgeActivity = State(
      initialValue: initialMode == .practice ? .learn : .interview
    )
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      header

      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          studySpaceSection

          if selectedStudySpaceID != nil {
            activitySection
          }

          if !isKnowledgeLearning {
            modePicker
          }

          if !isKnowledgeLearning {
            if isKnowledgeSession {
              groundedQuestionNote
            } else if mode != .behavioral {
              topicSection
            } else {
              behavioralTopicSection
            }

            if mode != .behavioral && mode != .systemDesign {
              difficultySection
            }

            durationSection

            if supportsHints {
              hintSection
            }
          }

          providerSection

          if selectedStudySpaceID == nil && !relevantBankQuestions.isEmpty {
            retrySection
          }
        }
        .padding(20)
      }

      footer
    }
    .frame(minWidth: 520, idealWidth: 560, minHeight: 620, idealHeight: 720)
    .background(EaselDesignSystem.Palette.surface(for: colorScheme))
    .onChange(of: mode) { _, newMode in
      selectedTopicIds.removeAll()
      selectedBankQuestionId = nil
      isTimed = newMode.isTimedByDefault
      durationMinutes = newMode == .drill ? 20 : 35
    }
    .onChange(of: knowledgeActivity) { _, activity in
      switch activity {
      case .learn:
        mode = .practice
        isTimed = false
        sourceAccess = .openBook
      case .interview:
        if mode == .practice {
          mode = .mockInterview
        }
        isTimed = mode.isTimedByDefault
      }
    }
    .onChange(of: selectedStudySpaceID) { _, studySpaceID in
      // Grounded sessions draw questions from the repository index, so the
      // generic topic/bank pickers no longer apply.
      selectedTopicIds.removeAll()
      selectedBankQuestionId = nil
      guard studySpaceID != nil else { return }
      knowledgeActivity = mode == .practice ? .learn : .interview
    }
    .fileImporter(
      isPresented: $isRepositoryImporterPresented,
      allowedContentTypes: [.folder],
      allowsMultipleSelection: false,
      onCompletion: importRepository
    )
    .task {
      await knowledgeLibrary.load()
    }
  }

  private var header: some View {
    HStack {
      Text("New Session")
        .font(EaselDesignSystem.Typography.interface(size: 16, weight: .semibold))
      Spacer()
    }
    .padding(.horizontal, 20)
    .frame(height: 52)
    .background(EaselDesignSystem.Palette.surface(for: colorScheme))
    .overlay(alignment: .bottom) {
      Rectangle()
        .fill(EaselDesignSystem.Palette.border(for: colorScheme))
        .frame(height: 1)
    }
  }

  private var isKnowledgeSession: Bool {
    selectedStudySpaceID != nil
  }

  private var isKnowledgeLearning: Bool {
    isKnowledgeSession && knowledgeActivity == .learn
  }

  private var selectedStudySpace: StudySpace? {
    knowledgeLibrary.studySpace(id: selectedStudySpaceID)
  }

  /// Replaces the generic topic chips for grounded interviews: questions come
  /// from the indexed repository, not from the standard topic catalog.
  private var groundedQuestionNote: some View {
    Label {
      Text(
        "Questions are drawn from “\(selectedStudySpace?.name ?? "your sources")” — Buddy asks about the repository's real code and design."
      )
      .font(.callout)
      .foregroundStyle(.secondary)
    } icon: {
      Image(systemName: "text.book.closed")
        .foregroundStyle(EaselDesignSystem.Palette.accent)
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      EaselDesignSystem.Palette.subtleSurface(for: colorScheme),
      in: RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.control)
    )
  }

  private var studySpaceSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        sectionTitle("Study Space (optional)")
        Spacer()
        if knowledgeLibrary.isImporting {
          ProgressView()
            .controlSize(.small)
          Text("Indexing…")
            .font(.callout)
            .foregroundStyle(.secondary)
        }
      }

      Picker("Study Space", selection: $selectedStudySpaceID) {
        Text("No sources").tag(String?.none)
        ForEach(readyStudySpaces) { studySpace in
          Text(studySpace.name).tag(Optional(studySpace.id))
        }
      }
      .labelsHidden()

      if let selectedStudySpace {
        Text(indexSummary(for: selectedStudySpace))
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      HStack {
        Text("Ground answers and interview questions in a reusable repository index.")
          .font(.callout)
          .foregroundStyle(.secondary)

        Spacer()

        Button("Add Repository", systemImage: "folder.badge.plus") {
          isRepositoryImporterPresented = true
        }
        .controlSize(.small)
        .disabled(knowledgeLibrary.isImporting)
      }

      if let errorMessage = knowledgeLibrary.errorMessage {
        Label(errorMessage, systemImage: "exclamationmark.triangle")
          .font(.callout)
          .foregroundStyle(EaselDesignSystem.Palette.danger)
      }
    }
  }

  private func indexSummary(for studySpace: StudySpace) -> String {
    let sources = knowledgeLibrary.sources(studySpaceID: studySpace.id)
    let files = sources.reduce(0) { $0 + $1.indexedFileCount }
    let passages = sources.reduce(0) { $0 + $1.chunkCount }
    return "\(files) files · \(passages) searchable passages"
  }

  private var readyStudySpaces: [StudySpace] {
    knowledgeLibrary.studySpaces.filter { studySpace in
      knowledgeLibrary.sources(studySpaceID: studySpace.id).contains {
        $0.indexStatus == .ready && $0.chunkCount > 0
      }
    }
  }

  private var activitySection: some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionTitle("How do you want to use these sources?")

      HStack(spacing: 10) {
        ForEach(KnowledgeActivity.allCases) { activity in
          activityButton(activity)
        }
      }

      if knowledgeActivity == .interview {
        Picker("Source access", selection: $sourceAccess) {
          ForEach(KnowledgeSourceAccess.allCases) { access in
            Text(access.displayName).tag(access)
          }
        }
        .pickerStyle(.segmented)
      }
    }
    .disabled(isModeSelectionLocked)
  }

  private func activityButton(_ activity: KnowledgeActivity) -> some View {
    let isSelected = knowledgeActivity == activity
    return Button {
      knowledgeActivity = activity
    } label: {
      VStack(alignment: .leading, spacing: 6) {
        Label(activity.displayName, systemImage: activity.systemImage)
          .font(.headline)
        Text(activity.summary)
          .font(.callout)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.leading)
      }
      .frame(maxWidth: .infinity, minHeight: 72, alignment: .topLeading)
      .padding(12)
      .background(
        isSelected
          ? EaselDesignSystem.Palette.selectedSurface(for: colorScheme)
          : EaselDesignSystem.Palette.subtleSurface(for: colorScheme),
        in: RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.control)
      )
      .overlay {
        RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.control)
          .stroke(
            isSelected
              ? EaselDesignSystem.Palette.accent
              : EaselDesignSystem.Palette.border(for: colorScheme),
            lineWidth: isSelected ? 2 : 1
          )
      }
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }

  private var modePicker: some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionTitle(selectedStudySpaceID == nil ? "Mode" : "Interview format")

      VStack(spacing: 6) {
        ForEach(availableModes) { candidate in
          SessionModeCard(
            mode: candidate,
            isSelected: mode == candidate,
            action: { mode = candidate }
          )
        }
      }
      .disabled(isModeSelectionLocked)
      .opacity(isModeSelectionLocked ? 0.6 : 1)
      .accessibilityElement(children: .contain)
      .accessibilityLabel("Session mode")
    }
  }

  private var availableModes: [SessionMode] {
    if selectedStudySpaceID != nil {
      return ModeGroup.displayOrder.filter { $0 != .practice }
    }
    return ModeGroup.displayOrder
  }

  private var topicCategories: [String] {
    switch mode {
    case .systemDesign: return ["system-design"]
    case .behavioral: return ["behavioral"]
    default:
      var categories = ["algorithms", "data-structures"]
      if specialization == .iOS {
        categories.append("ios")
      }
      return categories
    }
  }

  private var visibleTopics: [Topic] {
    topics.filter { topicCategories.contains($0.category) }
  }

  private var topicSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionTitle("Topics (optional — Buddy picks when empty)")
      FlowLayout(spacing: 6) {
        ForEach(visibleTopics) { topic in
          topicChip(topic)
        }
      }
    }
  }

  private var behavioralTopicSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionTitle("Themes")
      FlowLayout(spacing: 6) {
        ForEach(visibleTopics) { topic in
          topicChip(topic)
        }
      }
    }
  }

  private func topicChip(_ topic: Topic) -> some View {
    let isSelected = selectedTopicIds.contains(topic.id)
    return Button {
      if isSelected {
        selectedTopicIds.remove(topic.id)
      } else {
        selectedTopicIds.insert(topic.id)
      }
    } label: {
      Text(topic.displayName)
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(isSelected ? EaselDesignSystem.Palette.primaryActionForeground(for: colorScheme) : .primary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
          isSelected
            ? EaselDesignSystem.Palette.primaryAction(for: colorScheme)
            : EaselDesignSystem.Palette.subtleSurface(for: colorScheme),
          in: Capsule()
        )
        .overlay {
          Capsule().stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: isSelected ? 0 : 1)
        }
    }
    .buttonStyle(.plain)
  }

  private var difficultySection: some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionTitle("Difficulty")
      Picker("Difficulty", selection: $difficulty) {
        ForEach(Difficulty.allCases) { difficulty in
          Text(difficulty.displayName).tag(difficulty)
        }
      }
      .pickerStyle(.segmented)
      .labelsHidden()
    }
  }

  private var durationSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        sectionTitle("Duration")
        Spacer()
        Toggle("Timed", isOn: $isTimed)
          .toggleStyle(.switch)
          .controlSize(.mini)
          .disabled(mode == .practice)
      }

      if isTimed {
        Picker("Duration", selection: $durationMinutes) {
          ForEach(Self.durationPresets, id: \.self) { minutes in
            Text("\(minutes) min").tag(minutes)
          }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
      }
    }
  }

  private var supportsHints: Bool {
    mode == .mockInterview || mode == .drill || mode == .practice
  }

  private var hintSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionTitle("Hint budget")
      Stepper(value: $hintBudget, in: 0...10) {
        Text("\(hintBudget) hint\(hintBudget == 1 ? "" : "s")")
          .font(EaselDesignSystem.Typography.interface(size: 13))
      }
    }
  }

  private var providerSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionTitle("Provider")
      Picker("Provider", selection: $provider) {
        ForEach(ChatProvider.allCases) { provider in
          Text(provider.displayName).tag(provider)
        }
      }
      .pickerStyle(.segmented)
      .labelsHidden()
    }
  }

  private var relevantBankQuestions: [Question] {
    bankQuestions.filter { $0.mode == mode }
  }

  private var retrySection: some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionTitle("Retry from bank (optional)")
      VStack(spacing: 4) {
        ForEach(relevantBankQuestions.prefix(8)) { question in
          bankQuestionRow(question)
        }
      }
    }
  }

  private func bankQuestionRow(_ question: Question) -> some View {
    let isSelected = selectedBankQuestionId == question.id
    return Button {
      selectedBankQuestionId = isSelected ? nil : question.id
    } label: {
      HStack(spacing: 8) {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
          .foregroundStyle(isSelected ? EaselDesignSystem.Palette.accent : EaselDesignSystem.Palette.tertiaryText(for: colorScheme))

        Text(question.title)
          .font(EaselDesignSystem.Typography.interface(size: 13))
          .foregroundStyle(.primary)
          .lineLimit(1)

        Spacer()

        Text(question.difficulty.displayName)
          .font(.caption2)
          .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(
        isSelected ? EaselDesignSystem.Palette.selectedSurface(for: colorScheme) : Color.clear,
        in: RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.control)
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  private var footer: some View {
    HStack {
      Button("Cancel", action: onCancel)
        .keyboardShortcut(.cancelAction)

      Spacer()

      Button(startButtonTitle) {
        onStart(makeRequest())
      }
      .keyboardShortcut(.defaultAction)
      .buttonStyle(.borderedProminent)
      .disabled(knowledgeLibrary.isImporting)
    }
    .padding(.horizontal, 20)
    .frame(height: 60)
    .overlay(alignment: .top) {
      Rectangle()
        .fill(EaselDesignSystem.Palette.border(for: colorScheme))
        .frame(height: 1)
    }
  }

  private func makeRequest() -> ChatService.NewSessionRequest {
    ChatService.NewSessionRequest(
      mode: mode,
      question: isKnowledgeSession ? nil : relevantBankQuestions.first { $0.id == selectedBankQuestionId },
      topicIds: isKnowledgeSession ? [] : Array(selectedTopicIds).sorted(),
      difficulty: (mode == .behavioral || mode == .systemDesign) ? nil : difficulty,
      durationSeconds: isTimed ? durationMinutes * 60 : nil,
      hintBudget: supportsHints ? hintBudget : 0,
      provider: provider,
      knowledgeConfiguration: selectedStudySpaceID.map {
        KnowledgeSessionConfiguration(
          studySpaceID: $0,
          activity: knowledgeActivity,
          sourceAccess: sourceAccess
        )
      }
    )
  }

  private var startButtonTitle: String {
    guard selectedStudySpaceID != nil else { return "Start Session" }
    return knowledgeActivity == .learn ? "Start Learning" : "Start Interview"
  }

  private func importRepository(_ result: Result<[URL], Error>) {
    guard case .success(let urls) = result, let repositoryURL = urls.first else {
      return
    }
    Task {
      if let studySpace = await knowledgeLibrary.addRepository(at: repositoryURL) {
        selectedStudySpaceID = studySpace.id
      }
    }
  }

  private func sectionTitle(_ text: String) -> some View {
    Text(text)
      .font(.callout.weight(.medium))
      .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
  }
}

/// Minimal wrapping flow layout for topic chips.
struct FlowLayout: Layout {
  var spacing: CGFloat = 6

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let width = proposal.width ?? 400
    var x: CGFloat = 0
    var y: CGFloat = 0
    var rowHeight: CGFloat = 0

    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      if x + size.width > width, x > 0 {
        x = 0
        y += rowHeight + spacing
        rowHeight = 0
      }
      x += size.width + spacing
      rowHeight = max(rowHeight, size.height)
    }
    return CGSize(width: width, height: y + rowHeight)
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    var x = bounds.minX
    var y = bounds.minY
    var rowHeight: CGFloat = 0

    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      if x + size.width > bounds.maxX, x > bounds.minX {
        x = bounds.minX
        y += rowHeight + spacing
        rowHeight = 0
      }
      subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
      x += size.width + spacing
      rowHeight = max(rowHeight, size.height)
    }
  }
}
