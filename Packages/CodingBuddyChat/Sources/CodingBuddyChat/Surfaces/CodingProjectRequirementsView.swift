import CodingBuddyKit
import InterviewKit
import SwiftUI

public struct CodingProjectRequirementsView: View {
  private let workspacePath: String?
  private let question: Question?
  private let externalRefreshToken: Int
  private let canRegenerate: Bool
  private let isRegenerating: Bool
  private let onRegenerate: ((String) -> Void)?
  private let projectOpener: any CodingProjectOpening

  @State private var projectURL: URL?
  @State private var isOpeningProject = false
  @State private var openErrorMessage: String?
  /// Bug category the candidate is working on; nil follows the first section.
  @State private var selectedBugCategory: String?
  @Environment(\.colorScheme) private var colorScheme

  public init(
    workspacePath: String?,
    question: Question?,
    externalRefreshToken: Int = 0,
    canRegenerate: Bool = false,
    isRegenerating: Bool = false,
    onRegenerate: ((String) -> Void)? = nil,
    projectOpener: any CodingProjectOpening = SystemCodingProjectOpener()
  ) {
    self.workspacePath = workspacePath
    self.question = question
    self.externalRefreshToken = externalRefreshToken
    self.canRegenerate = canRegenerate
    self.isRegenerating = isRegenerating
    self.onRegenerate = onRegenerate
    self.projectOpener = projectOpener
  }

  public var body: some View {
    VStack(spacing: 0) {
      projectBar

      Rectangle()
        .fill(EaselDesignSystem.Palette.border(for: colorScheme))
        .frame(height: 1)

      if isRegenerating {
        regenerationBanner

        Rectangle()
          .fill(EaselDesignSystem.Palette.border(for: colorScheme))
          .frame(height: 1)
      }

      if let question {
        requirements(for: question)
      } else {
        VStack(spacing: 14) {
          ProgressView()
            .controlSize(.large)

          Text("Preparing your Xcode project…")
            .font(.title2)
            .bold()

          Text("The agent is generating and committing the baseline. The timer starts when the requirements are ready.")
            .font(.callout)
            .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
            .multilineTextAlignment(.center)
            .frame(maxWidth: 440)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Preparing your Xcode project")
        .accessibilityValue("Generating and committing the baseline")
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(EaselDesignSystem.Palette.canvas(for: colorScheme))
    .task(id: workspacePath) {
      refreshProjectLocation()
    }
    .onChange(of: externalRefreshToken) { _, _ in
      refreshProjectLocation()
    }
  }

  private var projectBar: some View {
    HStack(spacing: 10) {
      Label(projectName, systemImage: projectURL == nil ? "folder" : "checkmark.circle.fill")
        .font(.callout)
        .foregroundStyle(
          projectURL == nil
            ? EaselDesignSystem.Palette.secondaryText(for: colorScheme)
            : .primary
        )
        .lineLimit(1)
        .truncationMode(.middle)

      Spacer()

      if let openErrorMessage {
        Label(openErrorMessage, systemImage: "exclamationmark.triangle")
          .font(.caption)
          .foregroundStyle(EaselDesignSystem.Palette.danger)
          .lineLimit(2)
      }

      if let onRegenerate {
        CodingProjectRegenerateButton(
          canRegenerate: canRegenerate,
          isRegenerating: isRegenerating,
          onRegenerate: onRegenerate
        )
      }

      Button("Open in Xcode", systemImage: "hammer", action: openProject)
        .buttonStyle(.borderedProminent)
        .tint(EaselDesignSystem.Palette.accent)
        .controlSize(.small)
        .disabled(projectURL == nil || isOpeningProject)
    }
    .padding(.horizontal, 14)
    .frame(minHeight: 38)
    .background(EaselDesignSystem.Palette.surface(for: colorScheme))
  }

  /// Runs above the task list while the interviewer re-reads the diff, so the
  /// requirements on screen are visibly the previous round's until they change.
  private var regenerationBanner: some View {
    HStack(spacing: 10) {
      ProgressView()
        .controlSize(.small)

      Text("Reviewing your work and updating the task list…")
        .font(.callout)
        .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 14)
    .padding(.vertical, 8)
    .background(EaselDesignSystem.Palette.subtleSurface(for: colorScheme))
    .accessibilityElement(children: .combine)
  }

  private func requirements(for question: Question) -> some View {
    let sections = CodingProjectRequirementsParser.parse(question.promptMarkdown)
    let split = CodingProjectBugBoard.split(sections)

    return ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        VStack(alignment: .leading, spacing: 6) {
          Text(question.title)
            .font(.title2)
            .bold()
            .textSelection(.enabled)

          Text(
            split.board.isEmpty
              ? "Implement and verify these requirements in Xcode."
              : "Pick a bug category and fix its bugs in Xcode — each category runs easy to hard on its own."
          )
          .font(.callout)
          .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
        }

        if !split.board.isEmpty {
          bugBoard(split.board)
        }

        ForEach(split.remainder) { section in
          card {
            Text(section.title)
              .font(.headline)

            ForEach(section.items.indices, id: \.self) { index in
              Label {
                Text(markdown(section.items[index]))
                  .textSelection(.enabled)
                  .fixedSize(horizontal: false, vertical: true)
              } icon: {
                Image(systemName: "circle")
                  .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
                  .accessibilityHidden(true)
              }
            }
          }
        }
      }
      .padding(24)
      .frame(maxWidth: 760, alignment: .leading)
      .frame(maxWidth: .infinity)
    }
    .onChange(of: question.id) { _, _ in
      selectedBugCategory = nil
    }
  }

  // MARK: - Bug board

  @ViewBuilder
  private func bugBoard(_ board: [CodingProjectBugSection]) -> some View {
    let selected = board.first { $0.id == selectedBugCategory } ?? board[0]

    VStack(alignment: .leading, spacing: 14) {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          ForEach(board) { section in
            categoryChip(section, isSelected: section.id == selected.id)
          }
        }
        .padding(.vertical, 2)
      }

      card {
        HStack(alignment: .firstTextBaseline) {
          Text(selected.title)
            .font(.headline)

          Spacer()

          Text("\(selected.bugs.count) bug\(selected.bugs.count == 1 ? "" : "s")")
            .font(.caption)
            .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
        }

        ForEach(selected.bugs) { bug in
          HStack(alignment: .top, spacing: 10) {
            difficultyBadge(bug.difficulty)

            Text(markdown(bug.text))
              .textSelection(.enabled)
              .fixedSize(horizontal: false, vertical: true)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
          .padding(.vertical, 2)
        }
      }
    }
  }

  private func categoryChip(_ section: CodingProjectBugSection, isSelected: Bool) -> some View {
    Button {
      selectedBugCategory = section.id
    } label: {
      VStack(alignment: .leading, spacing: 2) {
        Text(CodingProjectBugBoard.categoryName(section.title))
          .font(.system(size: 13, weight: .semibold))

        Text("\(section.bugs.count) · \(section.difficultyRange)")
          .font(.caption2)
          .foregroundStyle(
            isSelected ? .primary : EaselDesignSystem.Palette.secondaryText(for: colorScheme)
          )
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 7)
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
            lineWidth: 1
          )
      }
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
  }

  private func difficultyBadge(_ difficulty: Difficulty) -> some View {
    Text(difficulty.displayName)
      .font(.system(size: 10, weight: .semibold))
      .foregroundStyle(difficultyColor(difficulty))
      .padding(.horizontal, 7)
      .padding(.vertical, 3)
      .background(difficultyColor(difficulty).opacity(0.16), in: Capsule())
      .frame(width: 66, alignment: .leading)
      .accessibilityLabel("\(difficulty.displayName) difficulty")
  }

  private func difficultyColor(_ difficulty: Difficulty) -> Color {
    switch difficulty {
    case .easy: return .green
    case .medium: return .orange
    case .hard: return .red
    }
  }

  private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 10, content: content)
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        EaselDesignSystem.Palette.surface(for: colorScheme),
        in: RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.card)
      )
      .overlay {
        RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.card)
          .stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
      }
  }

  private var projectName: String {
    projectURL?.deletingPathExtension().lastPathComponent
      ?? workspacePath.map { URL(fileURLWithPath: $0).lastPathComponent }
      ?? "Xcode project"
  }

  private func refreshProjectLocation() {
    guard let workspacePath else {
      projectURL = nil
      return
    }
    let workspaceURL = URL(fileURLWithPath: workspacePath, isDirectory: true)
    projectURL = CodingProjectLocator.projectURL(in: workspaceURL)
    if projectURL != nil {
      openErrorMessage = nil
    }
  }

  private func openProject() {
    guard let projectURL else { return }
    isOpeningProject = true
    openErrorMessage = nil
    Task {
      defer { isOpeningProject = false }
      do {
        try await projectOpener.openProject(at: projectURL)
      } catch {
        openErrorMessage = error.localizedDescription
      }
    }
  }

  private func markdown(_ text: String) -> AttributedString {
    (try? AttributedString(
      markdown: text,
      options: AttributedString.MarkdownParsingOptions(
        interpretedSyntax: .inlineOnlyPreservingWhitespace
      )
    )) ?? AttributedString(text)
  }
}
