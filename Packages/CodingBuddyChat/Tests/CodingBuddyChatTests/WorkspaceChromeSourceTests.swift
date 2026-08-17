import Foundation
import Testing

struct WorkspaceChromeSourceTests {
  @Test
  func floatingAccessoryIsAttachedToEditorBeforeConsole() throws {
    let source = try sourceContents(
      "Sources/CodingBuddyChat/Surfaces/WorkspaceEditorView.swift"
    )

    let accessoryRange = try #require(
      source.range(of: ".overlay(alignment: .bottomTrailing)")
    )
    let consoleRange = try #require(source.range(of: "if isConsoleVisible"))

    #expect(accessoryRange.lowerBound < consoleRange.lowerBound)
  }

  @Test
  func codingProjectSurfaceShowsRequirementsWithoutAnEditor() throws {
    let source = try sourceContents(
      "Sources/CodingBuddyChat/Surfaces/CodingProjectRequirementsView.swift"
    )

    #expect(source.contains("CodingProjectRequirementsParser.parse"))
    #expect(source.contains("Open in Xcode"))
    #expect(source.contains("projectOpener.openProject"))
    #expect(source.contains("ProgressView()"))
    #expect(!source.contains("ProjectResourceTextPreview"))
    #expect(!source.contains("SourceCodeEditorView"))
  }

  @Test
  func codingProjectSetupAcceptsAnOptionalMultilineBrief() throws {
    let source = try sourceContents(
      "Sources/CodingBuddyChat/Sidebar/CodingProjectSetupSection.swift"
    )

    #expect(source.contains("Project brief (optional)"))
    #expect(source.contains("axis: .vertical"))
    #expect(source.contains("CodingProjectBrief.maximumCharacterCount"))
    #expect(source.contains("Leave this blank"))
  }

  @Test
  func codingProjectRequirementsOfferRegenerationBesideTheXcodeButton() throws {
    let source = try sourceContents(
      "Sources/CodingBuddyChat/Surfaces/CodingProjectRequirementsView.swift"
    )

    let regenerateRange = try #require(source.range(of: "CodingProjectRegenerateButton("))
    let openRange = try #require(source.range(of: "Button(\"Open in Xcode\""))
    #expect(regenerateRange.lowerBound < openRange.lowerBound)

    #expect(source.contains("Reviewing your work and updating the task list…"))
  }

  @Test
  func gradedCodingProjectReportOffersTheSameRegenerateControl() throws {
    let source = try sourceContents(
      "Sources/CodingBuddyChat/Surfaces/SessionReportView.swift"
    )

    #expect(source.contains("headerAccessory: AnyView?"))
    #expect(source.contains("if let headerAccessory"))
  }

  @Test
  func regenerateButtonGatesOnTheServiceAndOpensTheNoteForm() throws {
    let source = try sourceContents(
      "Sources/CodingBuddyChat/Surfaces/CodingProjectRegenerateButton.swift"
    )

    #expect(source.contains("CodingProjectRegenerationForm"))
    #expect(source.contains(".popover(isPresented: $isFormPresented"))
    #expect(source.contains(".disabled(!canRegenerate)"))
    // The app tint is charcoal on a near-black canvas, so a bordered button
    // that inherits the default label color vanishes in dark mode.
    #expect(source.contains(".easelSecondaryButton()"))
    #expect(!source.contains(".buttonStyle(.bordered)"))
  }

  @Test
  func everySecondaryButtonUsesTheSchemeAwareControlStyle() throws {
    let sourcesDirectory = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("Sources/CodingBuddyChat")

    let files = FileManager.default
      .enumerator(at: sourcesDirectory, includingPropertiesForKeys: nil)?
      .compactMap { $0 as? URL }
      .filter { $0.pathExtension == "swift" } ?? []
    #expect(!files.isEmpty)

    // A bare `.bordered` button inherits a label color that disappears against
    // the app's dark surfaces — `easelSecondaryButton()` names its own.
    let offenders = try files.filter {
      try String(contentsOf: $0, encoding: .utf8).contains(".buttonStyle(.bordered)")
    }
    #expect(offenders.map(\.lastPathComponent) == [])
  }

  @Test
  func regenerationFormTakesAnOptionalBoundedNote() throws {
    let source = try sourceContents(
      "Sources/CodingBuddyChat/Surfaces/CodingProjectRegenerationForm.swift"
    )

    #expect(source.contains("axis: .vertical"))
    #expect(source.contains("CodingProjectBrief.maximumCharacterCount"))
    #expect(source.contains("CodingProjectBrief.limitedInput"))
    #expect(source.contains("Send to Interviewer"))
    #expect(source.contains(".keyboardShortcut(.cancelAction)"))
  }

  @Test
  func sidebarUsesFlatRowsAndOnlyTheTopBarCreateControl() throws {
    let source = try sourceContents(
      "Sources/CodingBuddyChat/Sidebar/SidebarView.swift"
    )

    #expect(source.contains("rows: sidebarViewModel.sessionRows"))
    #expect(!source.contains("modeGroupSection"))
    #expect(!source.contains("requestNewSession(mode:"))

    let createControlCount = source.components(
      separatedBy: "systemImage: \"plus\""
    ).count - 1
    #expect(createControlCount == 1)
  }

  @Test
  func sessionRowsShowTheirModeAsAccessibleMetadata() throws {
    let source = try sourceContents(
      "Sources/CodingBuddyChat/Sidebar/SidebarSessionRow.swift"
    )

    #expect(source.contains("SidebarSessionModeIcon(mode: row.mode)"))
    #expect(source.contains("Text(row.mode.displayName.uppercased())"))
    #expect(source.contains("Open \\(row.mode.displayName) session"))
  }

  private func sourceContents(_ relativePath: String) throws -> String {
    let testsDirectory = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let packageDirectory = testsDirectory.deletingLastPathComponent()
    return try String(
      contentsOf: packageDirectory.appendingPathComponent(relativePath),
      encoding: .utf8
    )
  }
}
