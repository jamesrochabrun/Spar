import Foundation

public actor RepositoryKnowledgeIndexer: RepositoryIndexing {
  private let storage: any KnowledgeStorageProtocol
  private let filePolicy: RepositoryFilePolicy
  private let chunker: RepositoryTextChunker
  private let fileManager: FileManager

  public init(
    storage: any KnowledgeStorageProtocol,
    filePolicy: RepositoryFilePolicy = RepositoryFilePolicy(),
    chunker: RepositoryTextChunker = RepositoryTextChunker(),
    fileManager: FileManager = .default
  ) {
    self.storage = storage
    self.filePolicy = filePolicy
    self.chunker = chunker
    self.fileManager = fileManager
  }

  public func indexRepository(
    at repositoryURL: URL,
    in studySpace: StudySpace
  ) async throws -> KnowledgeSource {
    var source = KnowledgeSource(
      studySpaceID: studySpace.id,
      displayName: repositoryURL.lastPathComponent,
      rootPath: repositoryURL.standardizedFileURL.path,
      indexStatus: .indexing
    )
    try await storage.saveSource(source)

    do {
      let indexedFiles = try readableFiles(in: repositoryURL)
      var chunks: [KnowledgeChunk] = []
      var versionMaterial: [String] = []

      for file in indexedFiles {
        try Task.checkCancellation()
        guard let text = try? String(contentsOf: file.url, encoding: .utf8),
              !text.contains("\0") else {
          continue
        }

        let fileChunks = chunker.chunks(
          text: text,
          relativePath: file.relativePath,
          studySpaceID: studySpace.id,
          sourceID: source.id
        )
        chunks.append(contentsOf: fileChunks)
        versionMaterial.append("\(file.relativePath):\(fileChunks.map(\.contentHash).joined())")
      }

      try await storage.replaceChunks(for: source.id, with: chunks)
      source.indexStatus = .ready
      source.indexedFileCount = Set(chunks.map(\.relativePath)).count
      source.chunkCount = chunks.count
      source.indexedAt = Date()
      source.contentVersion = RepositoryTextChunker.sha256(versionMaterial.sorted().joined(separator: "\n"))
      source.errorMessage = nil
      try await storage.saveSource(source)
      return source
    } catch {
      source.indexStatus = .failed
      source.errorMessage = error.localizedDescription
      try? await storage.saveSource(source)
      throw error
    }
  }

  private func readableFiles(in rootURL: URL) throws -> [(url: URL, relativePath: String)] {
    let resolvedRootURL = rootURL.resolvingSymlinksInPath().standardizedFileURL
    let rootPath = resolvedRootURL.path
    let resourceKeys: Set<URLResourceKey> = [.isDirectoryKey, .isRegularFileKey, .fileSizeKey]
    guard let enumerator = fileManager.enumerator(
      at: resolvedRootURL,
      includingPropertiesForKeys: Array(resourceKeys),
      options: [.skipsHiddenFiles]
    ) else {
      throw CocoaError(.fileReadUnknown)
    }

    var files: [(URL, String)] = []
    for case let fileURL as URL in enumerator {
      let values = try fileURL.resourceValues(forKeys: resourceKeys)
      if values.isDirectory == true {
        if filePolicy.shouldSkipDirectory(named: fileURL.lastPathComponent) {
          enumerator.skipDescendants()
        }
        continue
      }

      guard values.isRegularFile == true,
            filePolicy.shouldIndexFile(at: fileURL, fileSize: values.fileSize ?? 0) else {
        continue
      }

      let filePath = fileURL.standardizedFileURL.path
      guard filePath.hasPrefix(rootPath + "/") else { continue }
      let relativePath = String(filePath.dropFirst(rootPath.count + 1))
      guard !relativePath.isEmpty else { continue }
      files.append((fileURL, relativePath))
    }

    return files.sorted { $0.1.localizedStandardCompare($1.1) == .orderedAscending }
  }
}
