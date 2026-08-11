//
//  CodingBuddyTests.swift
//  CodingBuddyTests
//
//  Created by James Rochabrun on 3/22/26.
//

import Foundation
import Testing
@testable import CodingBuddy

struct CodingBuddyTests {
  @Test
  func visibleAppBrandingUsesSpar() throws {
    let workspace = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let relativePaths = [
      "CodingBuddy/CapsuleInputView.swift",
      "CodingBuddy/MainContentView.swift",
    ]

    for relativePath in relativePaths {
      let source = try String(
        contentsOf: workspace.appendingPathComponent(relativePath),
        encoding: .utf8
      )
      #expect(source.contains("AppBrand.name"))
      #expect(source.range(
        of: #"\b(Buddy|Easel|CodingBuddy)\b"#,
        options: .regularExpression
      ) == nil)
    }
  }
}
