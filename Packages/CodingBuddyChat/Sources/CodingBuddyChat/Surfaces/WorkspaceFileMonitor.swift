import Foundation

public protocol WorkspaceFileMonitoring: Sendable {
  /// Emits whenever the set of workspace files or their on-disk revisions
  /// changes. The initial directory state is treated as the baseline.
  func changes(in workspaceURL: URL) -> AsyncStream<Void>
}

public struct PollingWorkspaceFileMonitor: WorkspaceFileMonitoring {
  private let pollInterval: Duration

  public init(pollInterval: Duration = .milliseconds(400)) {
    self.pollInterval = pollInterval
  }

  public func changes(in workspaceURL: URL) -> AsyncStream<Void> {
    AsyncStream { continuation in
      let task = Task.detached(priority: .utility) {
        var previousSnapshot = WorkspaceDirectorySnapshot.capture(at: workspaceURL)

        while !Task.isCancelled {
          do {
            try await Task.sleep(for: pollInterval)
          } catch {
            break
          }

          let currentSnapshot = WorkspaceDirectorySnapshot.capture(at: workspaceURL)
          guard currentSnapshot != previousSnapshot else { continue }
          previousSnapshot = currentSnapshot
          continuation.yield()
        }

        continuation.finish()
      }

      continuation.onTermination = { @Sendable _ in
        task.cancel()
      }
    }
  }
}

struct WorkspaceDirectorySnapshot: Equatable, Sendable {
  struct Entry: Equatable, Sendable {
    let relativePath: String
    let byteCount: UInt64
    let modificationTime: TimeInterval
    let fileNumber: UInt64
  }

  let entries: [Entry]

  static func capture(at workspaceURL: URL) -> WorkspaceDirectorySnapshot {
    let fileManager = FileManager.default
    var entries: [Entry] = []

    if let enumerator = fileManager.enumerator(
      at: workspaceURL,
      includingPropertiesForKeys: [.isRegularFileKey],
      options: [.skipsHiddenFiles]
    ) {
      for case let fileURL as URL in enumerator {
        guard entries.count < 200 else { break }
        let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey])
        guard resourceValues?.isRegularFile == true else { continue }

        let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path)
        let relativePath = fileURL.path.hasPrefix(workspaceURL.path + "/")
          ? String(fileURL.path.dropFirst(workspaceURL.path.count + 1))
          : fileURL.lastPathComponent
        let byteCount = (attributes?[.size] as? NSNumber)?.uint64Value ?? 0
        let modificationTime = (attributes?[.modificationDate] as? Date)?.timeIntervalSinceReferenceDate ?? 0
        let fileNumber = (attributes?[.systemFileNumber] as? NSNumber)?.uint64Value ?? 0

        entries.append(Entry(
          relativePath: relativePath,
          byteCount: byteCount,
          modificationTime: modificationTime,
          fileNumber: fileNumber
        ))
      }
    }

    return WorkspaceDirectorySnapshot(entries: entries.sorted { $0.relativePath < $1.relativePath })
  }
}
