// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "CodingBuddyChat",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .library(
      name: "CodingBuddyChat",
      targets: ["CodingBuddyChat"]
    ),
  ],
  dependencies: [
    .package(path: "../CodingBuddyKit"),
    .package(path: "../InterviewKit"),
    .package(path: "../KnowledgeKit"),
    .package(path: "../BuddyMCPUI"),
    .package(path: "../AgentHubVoice"),
    .package(url: "https://github.com/jamesrochabrun/ClaudeCodeSDK", exact: "1.2.4"),
    .package(path: "../CodingBuddyClaudeCodeUI"),
    .package(path: "../CodingBuddyAgentHarness"),
    .package(path: "../CodingBuddyAgentMLX"),
    .package(url: "https://github.com/appstefan/highlightswift", from: "1.1.0"),
    .package(
      url: "https://github.com/jamesrochabrun/PierreDiffsSwift",
      exact: "1.2.4"
    ),
  ],
  targets: [
    .target(
      name: "CodingBuddyChat",
      dependencies: [
        "CodingBuddyKit",
        .product(name: "InterviewKit", package: "InterviewKit"),
        .product(name: "KnowledgeKit", package: "KnowledgeKit"),
        .product(name: "BuddyMCPUI", package: "BuddyMCPUI"),
        .product(name: "BuddyMCPApps", package: "BuddyMCPUI"),
        .product(name: "AgentHubVoice", package: "AgentHubVoice"),
        .product(name: "AgentHubVoicePanel", package: "AgentHubVoice"),
        .product(name: "ClaudeCodeSDK", package: "ClaudeCodeSDK"),
        .product(name: "ClaudeCodeCore", package: "CodingBuddyClaudeCodeUI"),
        .product(name: "CodingBuddyAgentHarness", package: "CodingBuddyAgentHarness"),
        .product(name: "CodingBuddyAgentMLX", package: "CodingBuddyAgentMLX"),
        .product(name: "HighlightSwift", package: "highlightswift"),
        .product(name: "PierreDiffsSwift", package: "PierreDiffsSwift"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
    .testTarget(
      name: "CodingBuddyChatTests",
      dependencies: [
        "CodingBuddyChat",
        "CodingBuddyKit",
        .product(name: "InterviewKit", package: "InterviewKit"),
        .product(name: "KnowledgeKit", package: "KnowledgeKit"),
        .product(name: "BuddyMCPUI", package: "BuddyMCPUI"),
        .product(name: "BuddyMCPApps", package: "BuddyMCPUI"),
        .product(name: "AgentHubVoice", package: "AgentHubVoice"),
        .product(name: "AgentHubVoicePanel", package: "AgentHubVoice"),
        .product(name: "ClaudeCodeCore", package: "CodingBuddyClaudeCodeUI"),
        .product(name: "HighlightSwift", package: "highlightswift"),
        .product(name: "PierreDiffsSwift", package: "PierreDiffsSwift"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
  ]
)
