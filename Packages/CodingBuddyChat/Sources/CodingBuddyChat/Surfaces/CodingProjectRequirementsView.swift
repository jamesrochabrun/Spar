import CodingBuddyKit
import InterviewKit
import SwiftUI

public struct CodingProjectRequirementsView: View {
  private let workspacePath: String?
  private let question: Question?
  private let externalRefreshToken: Int
  private let projectOpener: any CodingProjectOpening

  @State private var projectURL: URL?
  @State private var isOpeningProject = false
  @State private var openErrorMessage: String?
  @Environment(\.colorScheme) private var colorScheme

  public init(
    workspacePath: String?,
    question: Question?,
    externalRefreshToken: Int = 0,
    projectOpener: any CodingProjectOpening = SystemCodingProjectOpener()
  ) {
    self.workspacePath = workspacePath
    self.question = question
    self.externalRefreshToken = externalRefreshToken
    self.projectOpener = projectOpener
  }

  public var body: some View {
    VStack(spacing: 0) {
      projectBar

      Rectangle()
        .fill(EaselDesignSystem.Palette.border(for: colorScheme))
        .frame(height: 1)

      if let question {
        requirements(for: question)
      } else {
        VStack(spacing: 14) {
          ProgressView()
            .controlSize(.large)

          Text("Preparing your Xcode project…")
            .font(.title2)
            .bold()

          Text("The agent is generating, building, testing, and committing the baseline. The timer starts when the requirements are ready.")
            .font(.callout)
            .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
            .multilineTextAlignment(.center)
            .frame(maxWidth: 440)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Preparing your Xcode project")
        .accessibilityValue("Generating, building, testing, and committing the baseline")
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

      Button("Open in Xcode", systemImage: "hammer", action: openProject)
        .controlSize(.small)
        .disabled(projectURL == nil || isOpeningProject)
    }
    .padding(.horizontal, 14)
    .frame(minHeight: 38)
    .background(EaselDesignSystem.Palette.surface(for: colorScheme))
  }

  private func requirements(for question: Question) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        VStack(alignment: .leading, spacing: 6) {
          Text(question.title)
            .font(.title2)
            .bold()
            .textSelection(.enabled)

          Text("Implement and verify these requirements in Xcode.")
            .font(.callout)
            .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
        }

        ForEach(CodingProjectRequirementsParser.parse(question.promptMarkdown)) { section in
          VStack(alignment: .leading, spacing: 10) {
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
      }
      .padding(24)
      .frame(maxWidth: 760, alignment: .leading)
      .frame(maxWidth: .infinity)
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
