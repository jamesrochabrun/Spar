import Foundation
import Testing
@testable import CodingBuddyChat

@MainActor
struct FileRuleLibraryTests {

  private func makeTemporaryRoot() -> URL {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("rules-tests-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
  }

  private func write(_ body: String, named name: String, in root: URL) {
    try? body.write(
      to: root.appendingPathComponent(name),
      atomically: true,
      encoding: .utf8
    )
  }

  @Test
  func listsSupportedFilesSortedByNameAndIgnoresOthers() {
    let root = makeTemporaryRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    write("Use @Observable.", named: "swiftui-style.md", in: root)
    write("No force unwraps.", named: "Review Bar.txt", in: root)
    write("{}", named: "ignored.json", in: root)

    let library = FileRuleLibrary(rootDirectory: root)
    library.load()

    #expect(library.ruleSets.map(\.name) == ["Review Bar", "swiftui-style"])
    #expect(library.ruleSets.map(\.id) == ["review-bar", "swiftui-style"])
    #expect(library.errorMessage == nil)
  }

  @Test
  func createsTheFolderWhenItDoesNotExistYet() {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("rules-tests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let library = FileRuleLibrary(rootDirectory: root)
    library.load()

    #expect(FileManager.default.fileExists(atPath: root.path))
    #expect(library.ruleSets.isEmpty)
    #expect(library.errorMessage == nil)
  }

  @Test
  func importCopiesTheFileAndSuffixesNameCollisions() {
    let root = makeTemporaryRoot()
    let source = makeTemporaryRoot()
    defer {
      try? FileManager.default.removeItem(at: root)
      try? FileManager.default.removeItem(at: source)
    }
    write("Original.", named: "house.md", in: root)
    write("Imported.", named: "house.md", in: source)

    let library = FileRuleLibrary(rootDirectory: root)
    library.load()
    library.importRules(from: source.appendingPathComponent("house.md"))

    #expect(library.ruleSets.map(\.name) == ["house", "house-2"])
    // The original is never clobbered.
    let original = try! String(
      contentsOf: root.appendingPathComponent("house.md"),
      encoding: .utf8
    )
    #expect(original == "Original.")
  }

  @Test
  func resolveReadsBodiesFromDiskSoExternalEditsApply() {
    let root = makeTemporaryRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    write("Use @Observable.", named: "style.md", in: root)

    let library = FileRuleLibrary(rootDirectory: root)
    library.load()

    // Edited outside the app, with no reload in between.
    write("Use @Observable and async/await.", named: "style.md", in: root)

    let context = library.resolve(ids: ["style"])
    #expect(context.entries.first?.body == "Use @Observable and async/await.")
  }

  @Test
  func resolveSkipsUnknownIdsAndPreservesRequestedOrder() {
    let root = makeTemporaryRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    write("A.", named: "alpha.md", in: root)
    write("B.", named: "beta.md", in: root)

    let library = FileRuleLibrary(rootDirectory: root)
    library.load()

    #expect(library.resolve(ids: []).isEmpty)
    #expect(library.resolve(ids: ["gone"]).isEmpty)
    #expect(library.resolve(ids: ["beta", "gone", "alpha"]).names == ["beta", "alpha"])
  }

  /// The seam ChatService relies on: a file on disk becomes directives in the
  /// session prompt and in the grading turn.
  @Test
  func rulesOnDiskReachTheSessionPromptAndTheGradingTurn() {
    let root = makeTemporaryRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    write("Every view model uses @Observable.", named: "house-style.md", in: root)

    let library = FileRuleLibrary(rootDirectory: root)
    library.load()
    let context = library.resolve(ids: ["house-style"])

    let prefixes = BuddyAgentInstructions.prefixes(for: .codingProject, ruleContext: context)
    #expect(prefixes.claude.contains("Every view model uses @Observable."))

    let directive = BuddyAgentInstructions.evaluationDirective(
      mode: .codingProject,
      ruleContext: context
    )
    #expect(directive.contains("Every view model uses @Observable."))
  }

  @Test
  func deleteRemovesTheFileFromDiskAndTheLibrary() {
    let root = makeTemporaryRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    write("A.", named: "alpha.md", in: root)

    let library = FileRuleLibrary(rootDirectory: root)
    library.load()
    let alpha = try! #require(library.ruleSets.first)
    library.delete(alpha)

    #expect(library.ruleSets.isEmpty)
    #expect(!FileManager.default.fileExists(atPath: alpha.fileURL.path))
  }
}
