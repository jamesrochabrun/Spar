//
//  SidebarSessionSectionHeader.swift
//  CodingBuddyChat
//

import CodingBuddyKit
import SwiftUI

struct SidebarSessionSectionHeader: View {
  let title: String

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    Text(title.uppercased())
      .font(.caption.weight(.medium))
      .tracking(1.3)
      .foregroundStyle(EaselDesignSystem.Palette.tertiaryText(for: colorScheme))
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.leading, 12)
      .padding(.top, 15)
      .padding(.bottom, 6)
      .accessibilityAddTraits(.isHeader)
  }
}
