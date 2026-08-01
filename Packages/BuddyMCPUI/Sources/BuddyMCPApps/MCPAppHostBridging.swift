//
//  MCPAppHostBridging.swift
//  BuddyMCPApps
//
//  Small host seam the side panel routes callbacks through — CodingBuddy's
//  MCPAppSessionService conforms; AgentHub used its CLISessionsViewModel here.
//

import BuddyMCPUI
import Foundation

@MainActor
public protocol MCPAppHostBridging: AnyObject {
  func callMCPAppTool(
    resource: MCPAppResource,
    name: String,
    arguments: AgentHubMCPUIJSONValue?
  ) async throws -> AgentHubMCPUIJSONValue

  func readMCPAppResource(
    resource: MCPAppResource,
    uri: String
  ) async throws -> AgentHubMCPUIJSONValue

  func listMCPAppResources(
    resource: MCPAppResource
  ) async throws -> AgentHubMCPUIJSONValue

  func isMCPAppNetworkGranted(serverName: String, hosts: [String]) -> Bool

  func grantMCPAppNetwork(serverName: String, hosts: [String])
}
