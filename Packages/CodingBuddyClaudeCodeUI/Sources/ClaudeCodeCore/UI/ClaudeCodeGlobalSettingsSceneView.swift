//
//  ClaudeCodeGlobalSettingsSceneView.swift
//  ClaudeCodeUI
//

import SwiftUI

public struct ClaudeCodeGlobalSettingsSceneView: View {
  private let uiConfiguration: UIConfiguration
  private let chatViewModel: ChatViewModel?
  private let providedGlobalPreferences: GlobalPreferencesStorage?
  private let providedMCPToolsDiscovery: MCPToolsDiscoveryService?
  private let apiModelCatalog: (any APIModelCatalogProviding)?
  private let apiExtraContent: (() -> AnyView)?
  private let extraSections: (() -> AnyView)?

  @State private var ownedGlobalPreferences = GlobalPreferencesStorage()
  @State private var ownedMCPToolsDiscovery = MCPToolsDiscoveryService()

  public init(
    uiConfiguration: UIConfiguration = .default,
    chatViewModel: ChatViewModel? = nil,
    globalPreferences: GlobalPreferencesStorage? = nil,
    mcpToolsDiscovery: MCPToolsDiscoveryService? = nil,
    apiModelCatalog: (any APIModelCatalogProviding)? = nil,
    apiExtraContent: (() -> AnyView)? = nil,
    extraSections: (() -> AnyView)? = nil
  ) {
    self.uiConfiguration = uiConfiguration
    self.chatViewModel = chatViewModel
    self.providedGlobalPreferences = globalPreferences
    self.providedMCPToolsDiscovery = mcpToolsDiscovery
    self.apiModelCatalog = apiModelCatalog
    self.apiExtraContent = apiExtraContent
    self.extraSections = extraSections
  }

  public var body: some View {
    settingsView
      .environment(activeGlobalPreferences)
  }

  @ViewBuilder
  private var settingsView: some View {
    if let apiModelCatalog {
      GlobalSettingsView(
        uiConfiguration: uiConfiguration,
        chatViewModel: chatViewModel,
        mcpToolsDiscovery: activeMCPToolsDiscovery,
        apiModelCatalog: apiModelCatalog,
        apiExtraContent: apiExtraContent,
        extraSections: extraSections
      )
    } else {
      GlobalSettingsView(
        uiConfiguration: uiConfiguration,
        chatViewModel: chatViewModel,
        mcpToolsDiscovery: activeMCPToolsDiscovery,
        apiExtraContent: apiExtraContent,
        extraSections: extraSections
      )
    }
  }

  private var activeGlobalPreferences: GlobalPreferencesStorage {
    providedGlobalPreferences ?? ownedGlobalPreferences
  }

  private var activeMCPToolsDiscovery: MCPToolsDiscoveryService {
    providedMCPToolsDiscovery ?? ownedMCPToolsDiscovery
  }
}
