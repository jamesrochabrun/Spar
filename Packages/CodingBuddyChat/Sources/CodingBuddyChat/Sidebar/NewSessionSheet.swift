//
//  NewSessionSheet.swift
//  CodingBuddyChat
//

import ClaudeCodeCore
import CodingBuddyKit
import InterviewKit
import SwiftUI

/// "+" flow: mode, topic multi-select, difficulty, duration preset, hint
/// budget, provider, and optional retry-from-bank question.
public struct NewSessionSheet: View {

  private let topics: [Topic]
  private let bankQuestions: [Question]
  private let defaultProvider: ChatProvider
  private let specialization: InterviewSpecialization
  private let isModeSelectionLocked: Bool
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
  @Environment(\.colorScheme) private var colorScheme

  private static let durationPresets = [20, 35, 45, 60]

  public init(
    initialMode: SessionMode = .mockInterview,
    topics: [Topic],
    bankQuestions: [Question],
    defaultProvider: ChatProvider,
    specialization: InterviewSpecialization = .default,
    isModeSelectionLocked: Bool = false,
    onStart: @escaping (ChatService.NewSessionRequest) -> Void,
    onCancel: @escaping () -> Void
  ) {
    self.topics = topics
    self.bankQuestions = bankQuestions
    self.defaultProvider = defaultProvider
    self.specialization = specialization
    self.isModeSelectionLocked = isModeSelectionLocked
    self.onStart = onStart
    self.onCancel = onCancel
    self._mode = State(initialValue: initialMode)
    self._isTimed = State(initialValue: initialMode.isTimedByDefault)
    self._durationMinutes = State(initialValue: initialMode == .drill ? 20 : 35)
    self._provider = State(initialValue: defaultProvider)
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      header

      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          modePicker

          if mode != .behavioral {
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

          providerSection

          if !relevantBankQuestions.isEmpty {
            retrySection
          }
        }
        .padding(20)
      }

      footer
    }
    .frame(width: 480, height: 620)
    .background(EaselDesignSystem.Palette.surface(for: colorScheme))
    .onChange(of: mode) { _, newMode in
      selectedTopicIds.removeAll()
      selectedBankQuestionId = nil
      isTimed = newMode.isTimedByDefault
      durationMinutes = newMode == .drill ? 20 : 35
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

  private var modePicker: some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionTitle("Mode")
      Picker("Mode", selection: $mode) {
        ForEach(ModeGroup.displayOrder) { mode in
          Label(mode.displayName, systemImage: mode.systemImage).tag(mode)
        }
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .disabled(isModeSelectionLocked)
    }
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

      Button("Start Session") {
        onStart(makeRequest())
      }
      .keyboardShortcut(.defaultAction)
      .buttonStyle(.borderedProminent)
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
      question: relevantBankQuestions.first { $0.id == selectedBankQuestionId },
      topicIds: Array(selectedTopicIds).sorted(),
      difficulty: (mode == .behavioral || mode == .systemDesign) ? nil : difficulty,
      durationSeconds: isTimed ? durationMinutes * 60 : nil,
      hintBudget: supportsHints ? hintBudget : 0,
      provider: provider
    )
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
