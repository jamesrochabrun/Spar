import Foundation

public struct RepositoryFilePolicy: Sendable {
  public let maximumFileSize: Int

  private let excludedDirectoryNames: Set<String> = [
    ".build", ".git", ".idea", ".swiftpm", ".vscode",
    "build", "carthage", "deriveddata", "node_modules", "pods",
  ]

  private let excludedFileNames: Set<String> = [
    ".ds_store", ".env", "id_dsa", "id_ecdsa", "id_ed25519", "id_rsa",
  ]

  private let excludedExtensions: Set<String> = [
    "cer", "der", "dylib", "gif", "heic", "ico", "jpeg", "jpg",
    "mov", "mp3", "mp4", "p12", "pem", "png", "sqlite", "sqlite3",
    "so", "xcuserstate", "zip",
  ]

  private let allowedExtensions: Set<String> = [
    "c", "cc", "cpp", "css", "go", "h", "hpp", "html", "java",
    "js", "json", "jsx", "kt", "m", "md", "markdown", "mm", "php",
    "plist", "py", "rb", "rs", "scala", "sh", "sql", "swift", "toml",
    "ts", "tsx", "txt", "xml", "yaml", "yml",
  ]

  private let allowedExtensionlessNames: Set<String> = [
    "codeowners", "contributing", "dockerfile", "gemfile", "license",
    "makefile", "podfile", "readme",
  ]

  public init(maximumFileSize: Int = 750_000) {
    self.maximumFileSize = maximumFileSize
  }

  public func shouldSkipDirectory(named name: String) -> Bool {
    excludedDirectoryNames.contains(name.lowercased()) || name.hasPrefix(".")
  }

  public func shouldIndexFile(at url: URL, fileSize: Int) -> Bool {
    guard fileSize > 0, fileSize <= maximumFileSize else { return false }

    let lowercasedName = url.lastPathComponent.lowercased()
    if excludedFileNames.contains(lowercasedName) || lowercasedName.hasPrefix(".env.") {
      return false
    }

    let fileExtension = url.pathExtension.lowercased()
    if excludedExtensions.contains(fileExtension) {
      return false
    }
    if !fileExtension.isEmpty {
      return allowedExtensions.contains(fileExtension)
    }
    return allowedExtensionlessNames.contains(lowercasedName)
  }
}
