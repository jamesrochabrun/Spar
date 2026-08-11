//
//  SidebarSessionList.swift
//  CodingBuddyChat
//

import SwiftUI

struct SidebarSessionList: View {
  let selectedSessionID: String?
  let onSelect: (AttemptRow) -> Void
  let onDelete: (AttemptRow) -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private let sections: [SidebarSessionSection]
  private let rowIDs: [String]

  init(
    rows: [AttemptRow],
    selectedSessionID: String?,
    onSelect: @escaping (AttemptRow) -> Void,
    onDelete: @escaping (AttemptRow) -> Void
  ) {
    self.selectedSessionID = selectedSessionID
    self.onSelect = onSelect
    self.onDelete = onDelete
    sections = SidebarSessionSection.sections(from: rows)
    rowIDs = rows.map(\.id)
  }

  var body: some View {
    if sections.isEmpty {
      ContentUnavailableView {
        Label("No Sessions", systemImage: "bubble.left.and.bubble.right")
      } description: {
        Text("Use the + button in the top bar to create your first session.")
      }
    } else {
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 0) {
          ForEach(sections) { section in
            SidebarSessionSectionHeader(title: section.title)

            ForEach(section.rows) { row in
              SidebarSessionRow(
                row: row,
                isSelected: row.id == selectedSessionID,
                showsRecency: section.showsRecency,
                onSelect: { onSelect(row) },
                onDelete: { onDelete(row) }
              )
              .transition(.opacity.combined(with: .move(edge: .top)))
            }
          }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 12)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: rowIDs)
      }
    }
  }
}
