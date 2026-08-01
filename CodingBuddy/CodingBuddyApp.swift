//
//  CodingBuddyApp.swift
//  CodingBuddy
//

import EaselKit
import EaselChat
import SwiftUI

@main
struct CodingBuddyApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  var body: some Scene {
    Settings {
      EaselChatSettingsView(chatService: appDelegate.chatService)
        .tint(EaselDesignSystem.Palette.accent)
    }
    .commands {
      CommandGroup(after: .appInfo) {
        Button("Check for Updates...") {
          appDelegate.checkForUpdatesFromMenu(nil)
        }
      }
    }
  }
}
