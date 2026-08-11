//
//  SidebarSessionScoreBadge.swift
//  CodingBuddyChat
//

import InterviewKit
import SwiftUI

struct SidebarSessionScoreBadge: View {
  let score: Double

  @Environment(\.colorScheme) private var colorScheme
  @ScaledMetric(relativeTo: .caption) private var supportingPointSize =
    SidebarSessionTypography.supportingPointSize

  var body: some View {
    Text(Int(score.rounded()), format: .number)
      .font(
        .system(
          size: supportingPointSize,
          weight: SidebarSessionTypography.weight
        )
      )
      .monospacedDigit()
      .foregroundStyle(SessionMode.drill.sidebarAccent(for: colorScheme))
      .padding(.horizontal, 7)
      .padding(.vertical, 2)
      .background(
        SessionMode.drill.sidebarDarkAccent.opacity(0.16),
        in: Capsule()
      )
      .fixedSize()
      .help("Overall score: \(Int(score.rounded()))/100")
  }
}
