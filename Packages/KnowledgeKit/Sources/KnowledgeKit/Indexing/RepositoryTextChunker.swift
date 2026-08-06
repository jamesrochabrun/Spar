import CryptoKit
import Foundation

public struct RepositoryTextChunker: Sendable {
  private let targetCharacterCount: Int
  private let overlapLineCount: Int

  public init(targetCharacterCount: Int = 4_000, overlapLineCount: Int = 6) {
    self.targetCharacterCount = targetCharacterCount
    self.overlapLineCount = overlapLineCount
  }

  public func chunks(
    text: String,
    relativePath: String,
    studySpaceID: String,
    sourceID: String
  ) -> [KnowledgeChunk] {
    let lines = text.components(separatedBy: .newlines)
    guard !lines.isEmpty else { return [] }

    var chunks: [KnowledgeChunk] = []
    var startIndex = 0

    while startIndex < lines.count {
      var endIndex = startIndex
      var characterCount = 0

      while endIndex < lines.count {
        let nextCount = lines[endIndex].count + 1
        if endIndex > startIndex, characterCount + nextCount > targetCharacterCount {
          break
        }
        characterCount += nextCount
        endIndex += 1
      }

      let content = lines[startIndex..<endIndex].joined(separator: "\n")
      if !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        let contentHash = Self.sha256(content)
        let identifierMaterial = "\(sourceID)|\(relativePath)|\(startIndex + 1)|\(endIndex)|\(contentHash)"
        chunks.append(KnowledgeChunk(
          id: Self.sha256(identifierMaterial),
          studySpaceID: studySpaceID,
          sourceID: sourceID,
          relativePath: relativePath,
          startLine: startIndex + 1,
          endLine: endIndex,
          content: content,
          contentHash: contentHash
        ))
      }

      guard endIndex < lines.count else { break }
      startIndex = max(startIndex + 1, endIndex - overlapLineCount)
    }

    return chunks
  }

  public static func sha256(_ value: String) -> String {
    SHA256.hash(data: Data(value.utf8))
      .map { String(format: "%02x", $0) }
      .joined()
  }
}
