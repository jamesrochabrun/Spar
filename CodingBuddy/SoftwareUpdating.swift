//
//  SoftwareUpdating.swift
//  CodingBuddy
//

@MainActor
protocol SoftwareUpdating: AnyObject {
  func checkForUpdates()
}
