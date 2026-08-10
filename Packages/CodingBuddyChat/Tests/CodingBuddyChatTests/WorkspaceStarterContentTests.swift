import InterviewKit
import Testing

@testable import CodingBuddyChat

@Suite("Workspace starter content")
struct WorkspaceStarterContentTests {
  @Test
  func extractsRawSwiftAndPreservesItsIndentation() {
    let question = Question(
      mode: .practice,
      title: "Implement Counter",
      promptMarkdown: """
        Fill in `value()` while preserving the public API.

        ```swift
        import Foundation

        struct Counter {
          let start: Int

          func value() -> Int {
            fatalError("TODO")
          }
        }
        ```

        The starter project must compile before you begin.
        """,
      difficulty: .easy,
      topicIds: ["swift-basics"],
      languageHint: "swift"
    )

    let content = WorkspaceStarterContent.make(for: question)

    #expect(!content.contains("```"))
    #expect(!content.contains("// import Foundation"))
    #expect(content.contains("""
      import Foundation

      struct Counter {
        let start: Int

        func value() -> Int {
          fatalError("TODO")
        }
      }
      """))
    #expect(content.contains("// Fill in `value()` while preserving the public API."))
    #expect(content.hasSuffix("\n"))
  }

  @Test
  func ignoresNonSourceFencesInsteadOfCommentingThemIntoTheFile() {
    let question = Question(
      mode: .practice,
      title: "Decode Payload",
      promptMarkdown: """
        Use the sample payload.

        ```json
        {"value": 42}
        ```

        ```swift
        struct Payload {
          let value: Int
        }
        ```
        """,
      difficulty: .easy,
      languageHint: "swift"
    )

    let content = WorkspaceStarterContent.make(for: question)

    #expect(content.contains("struct Payload"))
    #expect(!content.contains("{\"value\": 42}"))
    #expect(!content.contains("```json"))
  }

  @Test
  func mapsLanguageAliasesToTheExpectedStarterFile() {
    #expect(WorkspaceStarterContent.fileName(for: nil) == "solution.swift")
    #expect(WorkspaceStarterContent.fileName(for: "py") == "solution.py")
    #expect(WorkspaceStarterContent.fileName(for: "c++") == "solution.cpp")
    #expect(WorkspaceStarterContent.fileName(for: "golang") == "solution.go")
  }
}
