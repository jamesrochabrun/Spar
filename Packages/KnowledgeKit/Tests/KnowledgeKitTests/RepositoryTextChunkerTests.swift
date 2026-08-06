import Testing
@testable import KnowledgeKit

struct RepositoryTextChunkerTests {
  @Test
  func chunksPreserveLineLocationsAndOverlap() {
    let text = (1...20).map { "line \($0) value" }.joined(separator: "\n")
    let chunker = RepositoryTextChunker(targetCharacterCount: 70, overlapLineCount: 2)

    let chunks = chunker.chunks(
      text: text,
      relativePath: "Sources/App.swift",
      studySpaceID: "space",
      sourceID: "source"
    )

    #expect(chunks.count > 1)
    #expect(chunks[0].startLine == 1)
    #expect(chunks[1].startLine <= chunks[0].endLine)
    #expect(chunks.allSatisfy { $0.locationLabel.hasPrefix("Sources/App.swift:") })
  }

  @Test
  func chunkIdentifiersAreDeterministic() {
    let chunker = RepositoryTextChunker()
    let arguments = (
      text: "struct Example {}\n",
      relativePath: "Example.swift",
      studySpaceID: "space",
      sourceID: "source"
    )

    let first = chunker.chunks(
      text: arguments.text,
      relativePath: arguments.relativePath,
      studySpaceID: arguments.studySpaceID,
      sourceID: arguments.sourceID
    )
    let second = chunker.chunks(
      text: arguments.text,
      relativePath: arguments.relativePath,
      studySpaceID: arguments.studySpaceID,
      sourceID: arguments.sourceID
    )

    #expect(first.map(\.id) == second.map(\.id))
  }

  @Test
  func chunksPreserveLeadingCodeIndentation() {
    let chunker = RepositoryTextChunker(targetCharacterCount: 30, overlapLineCount: 0)
    let chunks = chunker.chunks(
      text: "struct Example {\n  func run() {\n    print(\"Hi\")\n  }\n}",
      relativePath: "Example.swift",
      studySpaceID: "space",
      sourceID: "source"
    )

    #expect(chunks.count > 1)
    #expect(chunks[1].content.hasPrefix("  func") || chunks[1].content.hasPrefix("    print"))
  }
}
