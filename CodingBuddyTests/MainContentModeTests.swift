//
//  MainContentModeTests.swift
//  CodingBuddyTests
//

import Testing
@testable import CodingBuddy

@MainActor
struct MainContentModeTests {

  @Test
  func showingSessionLeavesDashboard() {
    var mode = MainContentMode.dashboard

    mode.showSession()

    #expect(mode == .session)
  }

  @Test
  func dashboardToggleMovesBetweenDashboardAndSession() {
    var mode = MainContentMode.session

    mode.toggleDashboard()
    #expect(mode == .dashboard)

    mode.toggleDashboard()
    #expect(mode == .session)
  }
}
