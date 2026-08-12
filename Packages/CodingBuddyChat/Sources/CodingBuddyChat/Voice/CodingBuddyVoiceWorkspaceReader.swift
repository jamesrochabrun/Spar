import Foundation

struct CodingBuddyVoiceWorkspaceEntry: Codable, Equatable, Sendable {
  let path: String
  let kind: String
  let size: Int?
}

protocol CodingBuddyVoiceWorkspaceReading: Sendable {
  func listEntries(
    in workspacePath: String,
    relativePath: String?
  ) async throws -> [CodingBuddyVoiceWorkspaceEntry]

  func readFile(
    in workspacePath: String,
    relativePath: String,
    characterLimit: Int
  ) async throws -> String
}

struct CodingBuddyVoiceWorkspaceReader: CodingBuddyVoiceWorkspaceReading {
  private static let entryLimit = 200
  private static let maximumReadCharacters = 20_000
  private static let maximumReadBytes = 512_000

  func listEntries(
    in workspacePath: String,
    relativePath: String?
  ) async throws -> [CodingBuddyVoiceWorkspaceEntry] {
    try await Task.detached(priority: .utility) {
      let root = try Self.workspaceRoot(at: workspacePath)
      let directory = try Self.scopedURL(
        root: root,
        relativePath: relativePath ?? ""
      )
      let values = try directory.resourceValues(forKeys: [.isDirectoryKey])
      guard values.isDirectory == true else {
        throw CodingBuddyVoiceWorkspaceError.notDirectory(relativePath ?? ".")
      }

      let children = try FileManager.default.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
        options: [.skipsHiddenFiles]
      )
      let sorted = children.sorted {
        $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
      }
      let baseRelativePath = relativePath?.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        ?? ""
      return try sorted.prefix(Self.entryLimit).compactMap { child in
        let childRelativePath = baseRelativePath.isEmpty
          ? child.lastPathComponent
          : baseRelativePath + "/" + child.lastPathComponent
        guard let scopedChild = try? Self.scopedURL(
          root: root,
          relativePath: childRelativePath
        ) else {
          return nil
        }
        let resourceValues = try scopedChild.resourceValues(
          forKeys: [.isDirectoryKey, .fileSizeKey]
        )
        let relative = scopedChild.path == root.path
          ? "."
          : String(scopedChild.path.dropFirst(root.path.count + 1))
        return CodingBuddyVoiceWorkspaceEntry(
          path: relative,
          kind: resourceValues.isDirectory == true ? "directory" : "file",
          size: resourceValues.isDirectory == true ? nil : resourceValues.fileSize
        )
      }
    }.value
  }

  func readFile(
    in workspacePath: String,
    relativePath: String,
    characterLimit: Int
  ) async throws -> String {
    try await Task.detached(priority: .utility) {
      let root = try Self.workspaceRoot(at: workspacePath)
      let file = try Self.scopedURL(root: root, relativePath: relativePath)
      let values = try file.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
      guard values.isRegularFile == true else {
        throw CodingBuddyVoiceWorkspaceError.notFile(relativePath)
      }
      guard (values.fileSize ?? 0) <= Self.maximumReadBytes else {
        throw CodingBuddyVoiceWorkspaceError.fileTooLarge
      }

      let data = try Data(contentsOf: file, options: [.mappedIfSafe])
      guard let text = String(data: data, encoding: .utf8) else {
        throw CodingBuddyVoiceWorkspaceError.notText
      }
      let limit = min(Self.maximumReadCharacters, max(1_000, characterLimit))
      if text.count > limit {
        return String(text.prefix(limit)) + "\n…[truncated]"
      }
      return text
    }.value
  }

  private static func workspaceRoot(at path: String) throws -> URL {
    let root = URL(fileURLWithPath: path, isDirectory: true)
      .standardizedFileURL
      .resolvingSymlinksInPath()
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory),
          isDirectory.boolValue else {
      throw CodingBuddyVoiceWorkspaceError.workspaceUnavailable
    }
    return root
  }

  private static func scopedURL(
    root: URL,
    relativePath: String
  ) throws -> URL {
    guard !relativePath.hasPrefix("/") else {
      throw CodingBuddyVoiceWorkspaceError.outsideWorkspace
    }
    let candidate = root
      .appendingPathComponent(relativePath)
      .standardizedFileURL
      .resolvingSymlinksInPath()
    guard candidate.path == root.path
      || candidate.path.hasPrefix(root.path + "/") else {
      throw CodingBuddyVoiceWorkspaceError.outsideWorkspace
    }
    return candidate
  }
}

private enum CodingBuddyVoiceWorkspaceError: LocalizedError {
  case workspaceUnavailable
  case outsideWorkspace
  case notDirectory(String)
  case notFile(String)
  case fileTooLarge
  case notText

  var errorDescription: String? {
    switch self {
    case .workspaceUnavailable:
      "The active attempt workspace is unavailable."
    case .outsideWorkspace:
      "Voice can only read files inside the active attempt workspace."
    case .notDirectory(let path):
      "\(path) is not a workspace directory."
    case .notFile(let path):
      "\(path) is not a workspace file."
    case .fileTooLarge:
      "That file is too large for voice review."
    case .notText:
      "That file is not UTF-8 text."
    }
  }
}
