import CodingBuddyKit
import InterviewKit
import SwiftUI

struct CodingProjectSetupSection: View {
  @Binding var usesImportedProject: Bool
  @Binding var projectBrief: String
  let importedProjectURL: URL?
  let onChooseProject: () -> Void

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Starting project")
        .font(.callout.weight(.medium))
        .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))

      Picker("Starting project", selection: $usesImportedProject) {
        Text("Generate for me").tag(false)
        Text("Import existing").tag(true)
      }
      .pickerStyle(.segmented)
      .labelsHidden()

      if usesImportedProject {
        HStack(spacing: 10) {
          Label(
            importedProjectURL?.lastPathComponent ?? "No project selected",
            systemImage: importedProjectURL == nil ? "folder" : "checkmark.circle.fill"
          )
          .font(.callout)
          .foregroundStyle(importedProjectURL == nil ? .secondary : .primary)
          .lineLimit(1)
          .truncationMode(.middle)

          Spacer()

          Button(
            importedProjectURL == nil ? "Choose Project" : "Choose Another",
            systemImage: "folder.badge.plus",
            action: onChooseProject
          )
          .controlSize(.small)
        }
        .padding(12)
        .background(
          EaselDesignSystem.Palette.subtleSurface(for: colorScheme),
          in: RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.control)
        )

        Text("\(AppBrand.name) copies the project into \(InterviewWorkspaceManager.xcodeProjectsDisplayPath), removes old Git metadata, and commits a clean baseline. Your original stays untouched.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      } else {
        Text("The interviewer creates a different compiling SwiftUI project in \(InterviewWorkspaceManager.xcodeProjectsDisplayPath), configures useful dependencies, and commits the baseline before giving you the feature.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text("Project brief (optional)")
            .font(.callout.weight(.medium))

          Spacer()

          Text("\(projectBrief.count)/\(CodingProjectBrief.maximumCharacterCount)")
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }

        TextField(
          "Example: Build a SwiftUI app that lists data from a public API, opens a detail screen, and includes three behavioral bugs for me to diagnose.",
          text: $projectBrief,
          axis: .vertical
        )
        .lineLimit(4...7)
        .textFieldStyle(.roundedBorder)
        .onChange(of: projectBrief) { _, value in
          let limited = CodingProjectBrief.limitedInput(value)
          if limited != value {
            projectBrief = limited
          }
        }

        Text(
          usesImportedProject
            ? "Describe the feature or debugging behavior you want to practice in the imported codebase."
            : "Describe the app, API, persistence, feature, or bugs you want. Leave this blank—or say “choose for me”—for a fully generated exercise."
        )
        .font(.callout)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      }
    }
  }
}
