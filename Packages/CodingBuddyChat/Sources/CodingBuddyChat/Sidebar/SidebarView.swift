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
  private let knowledgeLibrarySheetProvider: () -> AnyView

  @State private var showDeleteSessionConfirmation = false
  @State private var isKnowledgeLibraryPresented = false
  @State private var sessionToDelete: StoredSession?
  @Environment(\.colorScheme) private var colorScheme

  public init(
    sidebarViewModel: SidebarViewModel,
    reservesWindowControls: Bool = false,
    newSessionSheetProvider: @escaping () -> AnyView,
    knowledgeLibrarySheetProvider: @escaping () -> AnyView
  ) {
    self.sidebarViewModel = sidebarViewModel
    self.reservesWindowControls = reservesWindowControls
    self.newSessionSheetProvider = newSessionSheetProvider
    self.knowledgeLibrarySheetProvider = knowledgeLibrarySheetProvider
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
      Text("This permanently deletes the session, its evaluation data, and its project files. This action cannot be undone.")
    }
    .sheet(isPresented: $sidebarViewModel.isNewSessionSheetPresented) {
      newSessionSheetProvider()
    }
    .sheet(isPresented: $isKnowledgeLibraryPresented) {
      knowledgeLibrarySheetProvider()
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

      Button("Study Spaces", systemImage: "books.vertical") {
        isKnowledgeLibraryPresented = true
      }
      .labelStyle(.iconOnly)
      .font(.system(size: 13, weight: .medium))
      .buttonStyle(.plain)
      .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
      .help("Study Spaces")

      Button(
        "Dashboard",
        systemImage: "chart.bar.xaxis",
        action: sidebarViewModel.requestDashboard
      )
      .labelStyle(.iconOnly)
      .font(.system(size: 13, weight: .medium))
      .buttonStyle(.plain)
      .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
      .help("Dashboard")

      Button(
        "New session",
        systemImage: "plus",
        action: sidebarViewModel.requestNewSession
      )
      .labelStyle(.iconOnly)
      .font(.system(size: 14, weight: .medium))
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
      HStack(alignment: .center, spacing: 2) {
        Button {
          sidebarViewModel.toggleGroup(group.mode)
        } label: {
          HStack(alignment: .center, spacing: 8) {
            Image(systemName: group.systemImage)
              .font(.system(size: 12, weight: .medium))
              .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
              .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
              HStack(spacing: 8) {
                Text(group.displayName)
                  .font(EaselDesignSystem.Typography.interface(size: 13, weight: .semibold))
                  .foregroundStyle(.primary)

                if !group.rows.isEmpty {
                  Text("\(group.rows.count)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(EaselDesignSystem.Palette.tertiaryText(for: colorScheme))
                }
              }

              Text(group.mode.usageSubtitle)
                .font(.system(size: 10))
                .foregroundStyle(EaselDesignSystem.Palette.tertiaryText(for: colorScheme))
                .lineLimit(1)
                .truncationMode(.tail)
            }

            Spacer()
          }
          .padding(.leading, 8)
          .padding(.vertical, 5)
          .frame(maxWidth: .infinity, alignment: .leading)
          .contentShape(Rectangle())
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(.plain)

        Button {
          sidebarViewModel.requestNewSession(mode: group.mode)
        } label: {
          Label("New \(group.displayName) Session", systemImage: "plus")
            .labelStyle(.iconOnly)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
            .frame(width: 20, height: 20)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("New \(group.displayName) session")

        Button {
          sidebarViewModel.toggleGroup(group.mode)
        } label: {
          Label(
            group.isExpanded ? "Collapse \(group.displayName)" : "Expand \(group.displayName)",
            systemImage: "chevron.right"
          )
          .labelStyle(.iconOnly)
          .font(.system(size: 10, weight: .semibold))
          .foregroundStyle(EaselDesignSystem.Palette.tertiaryText(for: colorScheme))
          .rotationEffect(.degrees(group.isExpanded ? 90 : 0))
          .frame(width: 20, height: 20)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(group.isExpanded ? "Collapse \(group.displayName)" : "Expand \(group.displayName)")
        .padding(.trailing, 4)
      }

      if group.isExpanded {
        if group.rows.isEmpty {
          Button {
            sidebarViewModel.requestNewSession(mode: group.mode)
          } label: {
            Label(startFirstSessionTitle(for: group.mode), systemImage: "plus.circle")
              .font(.caption)
              .foregroundStyle(.tint)
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
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

  private func startFirstSessionTitle(for mode: SessionMode) -> String {
    switch mode {
    case .mockInterview: return "Start your first mock interview"
    case .drill: return "Start your first drill"
    case .practice: return "Start your first practice session"
    case .systemDesign: return "Start your first system design session"
    case .behavioral: return "Start your first behavioral session"
    }
  }

  private var groupAnimationValue: [String] {
    sidebarViewModel.modeGroups.map { group in
      let rowIDs = group.rows.map(\.id).joined(separator: ",")
      return "\(group.id):\(group.isExpanded):\(rowIDs)"
    }
  }
}
