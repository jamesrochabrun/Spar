//
//  CodingBuddyApp.swift
//  CodingBuddy
//

import CodingBuddyKit
import CodingBuddyChat
import SwiftUI

@main
struct CodingBuddyApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  var body: some Scene {
    Settings {
      CodingBuddyChatSettingsView(chatService: appDelegate.chatService)
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
