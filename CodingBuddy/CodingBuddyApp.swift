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
      CodingBuddyChatSettingsView(
        chatService: appDelegate.chatService,
        voiceController: appDelegate.voiceController
      )
        .tint(EaselDesignSystem.Palette.accent)
    }
    .commands {
      CommandGroup(after: .appInfo) {
        Button("Check for Updates...") {
          appDelegate.checkForUpdatesFromMenu(nil)
        }
      }
      CommandGroup(after: .sidebar) {
        Button("Show Voice") {
          appDelegate.toggleVoiceHUD(nil)
        }
        .keyboardShortcut("v", modifiers: [.command, .option])
      }
    }
  }
}
