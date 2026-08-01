// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "BuddyMCPUI",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .library(
      name: "BuddyMCPUI",
      targets: ["BuddyMCPUI"]
    ),
    .library(
      name: "BuddyMCPApps",
      targets: ["BuddyMCPApps"]
    ),
  ],
  targets: [
    // Tier 1: AgentHub's WKWebView JSON-RPC bridge, copied verbatim. Zero deps.
    .target(
      name: "BuddyMCPUI",
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
    // Tier 2/3: MCP clients, discovery actor, resolver, resource extraction,
    // and the side-panel host view.
    .target(
      name: "BuddyMCPApps",
      dependencies: ["BuddyMCPUI"],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
    .testTarget(
      name: "BuddyMCPUITests",
      dependencies: ["BuddyMCPUI", "BuddyMCPApps"],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
  ]
)
