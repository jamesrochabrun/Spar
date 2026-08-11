//
//  SidebarSessionModeIcon.swift
//  CodingBuddyChat
//

import InterviewKit
import SwiftUI

struct SidebarSessionModeIcon: View {
  let mode: SessionMode

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    Image(systemName: mode.sidebarSystemImage)
      .font(.system(size: 14, weight: .medium))
      .symbolRenderingMode(.monochrome)
      .foregroundStyle(mode.sidebarAccent(for: colorScheme))
      .frame(width: 28, height: 28)
      .background(
        mode.sidebarIconSurface,
        in: RoundedRectangle(cornerRadius: 8)
      )
      .accessibilityHidden(true)
  }
}
