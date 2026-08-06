import Foundation
import Testing
@testable import KnowledgeKit

struct RepositoryFilePolicyTests {
  private let policy = RepositoryFilePolicy()

  @Test
  func acceptsSourceAndDocumentationFiles() {
    #expect(policy.shouldIndexFile(at: URL(fileURLWithPath: "/repo/App.swift"), fileSize: 200))
    #expect(policy.shouldIndexFile(at: URL(fileURLWithPath: "/repo/README.md"), fileSize: 200))
    #expect(policy.shouldIndexFile(at: URL(fileURLWithPath: "/repo/Dockerfile"), fileSize: 200))
  }

  @Test
  func rejectsSecretsBinariesAndGeneratedDirectories() {
    #expect(!policy.shouldIndexFile(at: URL(fileURLWithPath: "/repo/.env"), fileSize: 200))
    #expect(!policy.shouldIndexFile(at: URL(fileURLWithPath: "/repo/signing.p12"), fileSize: 200))
    #expect(!policy.shouldIndexFile(at: URL(fileURLWithPath: "/repo/image.png"), fileSize: 200))
    #expect(policy.shouldSkipDirectory(named: ".git"))
    #expect(policy.shouldSkipDirectory(named: "node_modules"))
    #expect(policy.shouldSkipDirectory(named: "DerivedData"))
  }
}
