//
//  SidebarView.swift
//  CodingBuddyChat
//

import ClaudeCodeCore
import CodingBuddyKit
import Foundation
import InterviewKit
import SwiftUI

public struct SidebarView: View {
  @Bindable var sidebarViewModel: SidebarViewModel
  private let reservesWindowControls: Bool
  private let newSessionSheetProvider: () -> AnyView

  @State private var showDeleteSessionConfirmation = false
  @State private var sessionToDelete: StoredSession?
  @Environment(\.colorScheme) private var colorScheme

  public init(
    sidebarViewModel: SidebarViewModel,
    reservesWindowControls: Bool = false,
    newSessionSheetProvider: @escaping () -> AnyView
  ) {
    self.sidebarViewModel = sidebarViewModel
    self.reservesWindowControls = reservesWindowControls
    self.newSessionSheetProvider = newSessionSheetProvider
  }

  public var body: some View {
    VStack(spacing: 0) {
      headerView

      Rectangle()
        .fill(EaselDesignSystem.Palette.border(for: colorScheme))
        .frame(height: 1)

      ScrollView {
        LazyVStack(alignment: .leading, spacing: 10) {
          ForEach(sidebarViewModel.modeGroups) { group in
            modeGroupSection(group)
          }
        }
        .padding(12)
        .animation(.easeInOut(duration: 0.22), value: groupAnimationValue)
      }
    }
    .background(EaselDesignSystem.Palette.canvas(for: colorScheme))
    .tint(EaselDesignSystem.Palette.accent)
    .alert("Delete Session", isPresented: $showDeleteSessionConfirmation) {
      Button("Cancel", role: .cancel) {
        sessionToDelete = nil
      }
      Button("Delete", role: .destructive) {
        if let session = sessionToDelete {
          sidebarViewModel.deleteSession(session)
          sessionToDelete = nil
        }
      }
    } message: {
      Text("Are you sure you want to delete this session? This action cannot be undone.")
    }
    .sheet(isPresented: $sidebarViewModel.isNewSessionSheetPresented) {
      newSessionSheetProvider()
    }
    .task {
      await sidebarViewModel.loadSessions()
    }
  }

  private var headerView: some View {
    HStack(alignment: .center, spacing: 5) {
      Image("easelmenubar")
        .renderingMode(.template)
        .resizable()
        .scaledToFit()
        .foregroundStyle(headerIconForegroundColor)
        .frame(width: 16, height: 16)
        .accessibilityHidden(true)

      Text("CodingBuddy")
        .font(EaselDesignSystem.Typography.interface(size: 16, weight: .semibold))
        .foregroundStyle(.primary)
        .lineLimit(1)

      Spacer()

      Button {
        sidebarViewModel.requestDashboard()
      } label: {
        Image(systemName: "chart.bar.xaxis")
          .font(.system(size: 13, weight: .medium))
      }
      .buttonStyle(.plain)
      .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
      .help("Dashboard")

      Button {
        sidebarViewModel.requestNewSession()
      } label: {
        Image(systemName: "plus")
          .font(.system(size: 14, weight: .medium))
      }
      .buttonStyle(.plain)
      .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
      .help("New session")
    }
    .padding(.leading, headerLeadingPadding)
    .padding(.trailing, 16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .frame(height: EaselDesignSystem.Spacing.toolbarHeight)
  }

  private var headerIconForegroundColor: Color {
    colorScheme == .dark ? .white : EaselDesignSystem.Palette.accent
  }

  private var headerLeadingPadding: CGFloat {
    reservesWindowControls ? 78 : 16
  }

  @ViewBuilder
  private func modeGroupSection(_ group: ModeGroup) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Button {
        sidebarViewModel.toggleGroup(group.mode)
      } label: {
        HStack(spacing: 8) {
          Image(systemName: group.systemImage)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
            .frame(width: 16)

          Text(group.displayName)
            .font(EaselDesignSystem.Typography.interface(size: 13, weight: .semibold))
            .foregroundStyle(.primary)

          if !group.rows.isEmpty {
            Text("\(group.rows.count)")
              .font(.system(.caption2, design: .monospaced))
              .foregroundStyle(EaselDesignSystem.Palette.tertiaryText(for: colorScheme))
          }

          Spacer()

          Image(systemName: "chevron.right")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(EaselDesignSystem.Palette.tertiaryText(for: colorScheme))
            .rotationEffect(.degrees(group.isExpanded ? 90 : 0))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)

      if group.isExpanded {
        if group.rows.isEmpty {
          Text("No sessions yet")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 12)
            .padding(.bottom, 4)
        } else {
          ForEach(group.rows) { row in
            SidebarSessionRow(
              row: row,
              isSelected: row.id == sidebarViewModel.selectedSessionId,
              onSelect: {
                sidebarViewModel.selectSession(row.session)
              },
              onDelete: {
                sessionToDelete = row.session
                showDeleteSessionConfirmation = true
              }
            )
            .padding(.leading, 6)
            .transition(.opacity.combined(with: .move(edge: .top)))
          }
        }
      }
    }
  }

  private var groupAnimationValue: [String] {
    sidebarViewModel.modeGroups.map { group in
      let rowIDs = group.rows.map(\.id).joined(separator: ",")
      return "\(group.id):\(group.isExpanded):\(rowIDs)"
    }
  }
}
