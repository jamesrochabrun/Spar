//
//  SidebarSessionList.swift
//  CodingBuddyChat
//

import SwiftUI

struct SidebarSessionList: View {
  let rows: [AttemptRow]
  let selectedSessionID: String?
  let onSelect: (AttemptRow) -> Void
  let onDelete: (AttemptRow) -> Void

  var body: some View {
    if rows.isEmpty {
      ContentUnavailableView {
        Label("No Sessions", systemImage: "bubble.left.and.bubble.right")
      } description: {
        Text("Use the + button in the top bar to create your first session.")
      }
    } else {
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 6) {
          ForEach(rows) { row in
            SidebarSessionRow(
              row: row,
              isSelected: row.id == selectedSessionID,
              onSelect: { onSelect(row) },
              onDelete: { onDelete(row) }
            )
            .transition(.opacity.combined(with: .move(edge: .top)))
          }
        }
        .padding(12)
        .animation(.easeInOut(duration: 0.22), value: rows.map(\.id))
      }
    }
  }
}
