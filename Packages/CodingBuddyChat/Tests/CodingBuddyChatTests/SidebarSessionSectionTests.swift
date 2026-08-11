//
//  SidebarSessionSectionTests.swift
//  CodingBuddyChatTests
//

import ClaudeCodeCore
import Foundation
import Testing
@testable import CodingBuddyChat

struct SidebarSessionSectionTests {
  @Test
  func sectionsUseRollingDayWindowsAndPreserveRowOrder() {
    let now = Date(timeIntervalSince1970: 1_786_474_200)

    let rows = [
      row(id: "today", lastAccessedAt: now.addingTimeInterval(-60)),
      row(id: "today-23h", lastAccessedAt: now.addingTimeInterval(-23 * 60 * 60)),
      row(id: "yesterday", lastAccessedAt: now.addingTimeInterval(-25 * 60 * 60)),
      row(id: "yesterday-47h", lastAccessedAt: now.addingTimeInterval(-47 * 60 * 60)),
      row(id: "earlier", lastAccessedAt: now.addingTimeInterval(-49 * 60 * 60)),
    ]

    let sections = SidebarSessionSection.sections(
      from: rows,
      now: now
    )

    #expect(sections.map(\.title) == ["Today", "Yesterday", "Earlier"])
    #expect(sections[0].rows.map(\.id) == ["today", "today-23h"])
    #expect(sections[1].rows.map(\.id) == ["yesterday", "yesterday-47h"])
    #expect(sections[2].rows.map(\.id) == ["earlier"])
    #expect(sections.map(\.showsRecency) == [true, false, true])
  }

  @Test
  func emptyDateBucketsAreOmitted() {
    let now = Date(timeIntervalSince1970: 1_786_474_200)
    let sections = SidebarSessionSection.sections(
      from: [row(id: "today", lastAccessedAt: now)],
      now: now
    )

    #expect(sections.count == 1)
    #expect(sections.first?.title == "Today")
  }

  private func row(id: String, lastAccessedAt: Date) -> AttemptRow {
    AttemptRow(session: StoredSession(
      id: id,
      createdAt: lastAccessedAt.addingTimeInterval(-60),
      firstUserMessage: id,
      lastAccessedAt: lastAccessedAt,
      workingDirectory: "/tmp/\(id)"
    ))
  }
}
