import Foundation

public enum CodingProjectLocator {
  public static func projectURL(in rootURL: URL) -> URL? {
    if isXcodeContainer(rootURL) {
      return rootURL
    }

    guard let enumerator = FileManager.default.enumerator(
      at: rootURL,
      includingPropertiesForKeys: [.isDirectoryKey],
      options: [.skipsHiddenFiles, .skipsPackageDescendants]
    ) else {
      return nil
    }

    var candidates: [URL] = []
    for case let fileURL as URL in enumerator where isXcodeContainer(fileURL) {
      candidates.append(fileURL)
      if candidates.count >= 20 {
        break
      }
    }

    return candidates.sorted(by: isPreferred(_:over:)).first
  }

  private static func isXcodeContainer(_ url: URL) -> Bool {
    url.pathExtension == "xcworkspace" || url.pathExtension == "xcodeproj"
  }

  private static func isPreferred(_ lhs: URL, over rhs: URL) -> Bool {
    let lhsDepth = lhs.pathComponents.count
    let rhsDepth = rhs.pathComponents.count
    if lhsDepth != rhsDepth {
      return lhsDepth < rhsDepth
    }
    if lhs.pathExtension != rhs.pathExtension {
      return lhs.pathExtension == "xcworkspace"
    }
    return lhs.path < rhs.path
  }
}
