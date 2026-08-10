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

      SidebarSessionList(
        rows: sidebarViewModel.sessionRows,
        selectedSessionID: sidebarViewModel.selectedSessionId,
        onSelect: { row in
          sidebarViewModel.selectSession(row.session)
        },
        onDelete: { row in
          sessionToDelete = row.session
          showDeleteSessionConfirmation = true
        }
      )
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
      Image(systemName: AppBrand.symbolName)
        .font(.system(size: 15, weight: .medium))
        .symbolRenderingMode(.hierarchical)
        .foregroundStyle(headerIconForegroundColor)
        .frame(width: 16, height: 16)
        .accessibilityHidden(true)

      Text(AppBrand.name)
        .font(EaselDesignSystem.Typography.interface(size: 16, weight: .semibold))
        .foregroundStyle(.primary)
        .lineLimit(1)

      Spacer()

      Button("Learning Library", systemImage: "books.vertical") {
        isKnowledgeLibraryPresented = true
      }
      .labelStyle(.iconOnly)
      .font(.system(size: 13, weight: .medium))
      .buttonStyle(.plain)
      .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
      .help("Learning Library")

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

}
