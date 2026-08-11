//
//  SessionMode+SidebarStyle.swift
//  CodingBuddyChat
//

import InterviewKit
import SwiftUI

extension SessionMode {
  var sidebarSystemImage: String {
    switch self {
    case .mockInterview: return "person.2"
    case .practice: return "book.closed"
    case .systemDesign: return "rectangle.3.group"
    case .behavioral: return "bubble.left"
    case .drill: return "bolt"
    }
  }

  func sidebarAccent(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? sidebarDarkAccent : sidebarLightAccent
  }

  var sidebarIconSurface: Color {
    sidebarDarkAccent.opacity(0.14)
  }

  var sidebarDarkAccent: Color {
    switch self {
    case .mockInterview:
      return Color(
        red: 138.0 / 255.0,
        green: 118.0 / 255.0,
        blue: 168.0 / 255.0
      )
    case .practice:
      return Color(
        red: 107.0 / 255.0,
        green: 143.0 / 255.0,
        blue: 107.0 / 255.0
      )
    case .systemDesign:
      return Color(
        red: 92.0 / 255.0,
        green: 130.0 / 255.0,
        blue: 168.0 / 255.0
      )
    case .behavioral:
      return Color(
        red: 79.0 / 255.0,
        green: 140.0 / 255.0,
        blue: 132.0 / 255.0
      )
    case .drill:
      return Color(
        red: 163.0 / 255.0,
        green: 138.0 / 255.0,
        blue: 85.0 / 255.0
      )
    }
  }

  var sidebarLightAccent: Color {
    switch self {
    case .mockInterview:
      return Color(
        red: 107.0 / 255.0,
        green: 87.0 / 255.0,
        blue: 136.0 / 255.0
      )
    case .practice:
      return Color(
        red: 76.0 / 255.0,
        green: 110.0 / 255.0,
        blue: 76.0 / 255.0
      )
    case .systemDesign:
      return Color(
        red: 62.0 / 255.0,
        green: 97.0 / 255.0,
        blue: 131.0 / 255.0
      )
    case .behavioral:
      return Color(
        red: 49.0 / 255.0,
        green: 107.0 / 255.0,
        blue: 99.0 / 255.0
      )
    case .drill:
      return Color(
        red: 122.0 / 255.0,
        green: 101.0 / 255.0,
        blue: 53.0 / 255.0
      )
    }
  }
}
