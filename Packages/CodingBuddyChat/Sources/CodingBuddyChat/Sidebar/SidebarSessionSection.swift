//
//  SidebarSessionSection.swift
//  CodingBuddyChat
//

import Foundation

enum SidebarSessionSection: Identifiable {
  case today([AttemptRow])
  case yesterday([AttemptRow])
  case earlier([AttemptRow])

  var id: String {
    switch self {
    case .today: return "today"
    case .yesterday: return "yesterday"
    case .earlier: return "earlier"
    }
  }

  var title: String {
    switch self {
    case .today: return "Today"
    case .yesterday: return "Yesterday"
    case .earlier: return "Earlier"
    }
  }

  var rows: [AttemptRow] {
    switch self {
    case .today(let rows), .yesterday(let rows), .earlier(let rows):
      return rows
    }
  }

  var showsRecency: Bool {
    if case .yesterday = self {
      return false
    }
    return true
  }

  static func sections(
    from rows: [AttemptRow],
    now: Date = Date()
  ) -> [SidebarSessionSection] {
    var today: [AttemptRow] = []
    var yesterday: [AttemptRow] = []
    var earlier: [AttemptRow] = []

    for row in rows {
      // These are rolling recency windows: the reference keeps a 23-hour-old
      // session in Today even when it crosses a calendar-day boundary.
      let elapsed = max(0, now.timeIntervalSince(row.session.lastAccessedAt))
      if elapsed < 86_400 {
        today.append(row)
      } else if elapsed < 172_800 {
        yesterday.append(row)
      } else {
        earlier.append(row)
      }
    }

    var sections: [SidebarSessionSection] = []
    if !today.isEmpty {
      sections.append(.today(today))
    }
    if !yesterday.isEmpty {
      sections.append(.yesterday(yesterday))
    }
    if !earlier.isEmpty {
      sections.append(.earlier(earlier))
    }
    return sections
  }
}
