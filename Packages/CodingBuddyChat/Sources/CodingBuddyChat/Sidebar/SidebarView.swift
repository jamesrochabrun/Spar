//
//  SidebarView.swift
//  CodingBuddyChat
//

import ClaudeCodeCore
import CodingBuddyKit
import Foundation
import SwiftUI

public struct SidebarView: View {
  @Bindable var sidebarViewModel: SidebarViewModel
  private let reservesWindowControls: Bool

  @State private var showDeleteSessionConfirmation = false
  @State private var sessionToDelete: StoredSession?
  @Environment(\.colorScheme) private var colorScheme

  public init(sidebarViewModel: SidebarViewModel, reservesWindowControls: Bool = false) {
    self.sidebarViewModel = sidebarViewModel
    self.reservesWindowControls = reservesWindowControls
  }

  public var body: some View {
    VStack(spacing: 0) {
      headerView

      Rectangle()
        .fill(EaselDesignSystem.Palette.border(for: colorScheme))
        .frame(height: 1)

      ScrollView {
        VStack(alignment: .leading, spacing: 8) {
          sessionListHeader

          if sidebarViewModel.sessions.isEmpty {
            Text("No sessions yet")
              .font(.callout)
              .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.vertical, 8)
          } else {
            LazyVStack(alignment: .leading, spacing: 6) {
              ForEach(sidebarViewModel.sessions) { session in
                SidebarSessionRow(
                  session: session,
                  isSelected: session.id == sidebarViewModel.selectedSessionId,
                  onSelect: {
                    sidebarViewModel.selectSession(session)
                  },
                  onDelete: {
                    sessionToDelete = session
                    showDeleteSessionConfirmation = true
                  }
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
              }
            }
            .animation(.easeInOut(duration: 0.22), value: sidebarViewModel.sessions.map(\.id))
          }
        }
        .padding(12)
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
        sidebarViewModel.requestNewChat(workingDirectory: nil)
      } label: {
        Image(systemName: "square.and.pencil")
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

  private var sessionListHeader: some View {
    HStack {
      Text("Sessions")
        .font(EaselDesignSystem.Typography.interface(size: 14, weight: .semibold))
        .foregroundStyle(.primary)

      Spacer()

      Button {
        Task {
          await sidebarViewModel.loadSessions()
        }
      } label: {
        Image(systemName: "arrow.clockwise")
          .font(.system(size: 13, weight: .medium))
      }
      .buttonStyle(.plain)
      .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
      .help("Refresh sessions")
    }
  }
}
