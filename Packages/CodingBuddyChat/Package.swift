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
    .package(url: "https://github.com/jamesrochabrun/ClaudeCodeSDK", exact: "1.2.4"),
    .package(path: "../CodingBuddyClaudeCodeUI"),
    .package(path: "../CodingBuddyAgentHarness"),
    .package(path: "../CodingBuddyAgentMLX"),
    .package(url: "https://github.com/appstefan/highlightswift", from: "1.1.0"),
    .package(url: "https://github.com/CodeEditApp/CodeEditSourceEditor", exact: "0.15.2"),
    .package(url: "https://github.com/CodeEditApp/CodeEditLanguages", exact: "0.1.20"),
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
        .product(name: "ClaudeCodeSDK", package: "ClaudeCodeSDK"),
        .product(name: "ClaudeCodeCore", package: "CodingBuddyClaudeCodeUI"),
        .product(name: "CodingBuddyAgentHarness", package: "CodingBuddyAgentHarness"),
        .product(name: "CodingBuddyAgentMLX", package: "CodingBuddyAgentMLX"),
        .product(name: "HighlightSwift", package: "highlightswift"),
        .product(name: "CodeEditSourceEditor", package: "CodeEditSourceEditor"),
        .product(name: "CodeEditLanguages", package: "CodeEditLanguages"),
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
        .product(name: "ClaudeCodeCore", package: "CodingBuddyClaudeCodeUI"),
        .product(name: "HighlightSwift", package: "highlightswift"),
        .product(name: "CodeEditSourceEditor", package: "CodeEditSourceEditor"),
        .product(name: "CodeEditLanguages", package: "CodeEditLanguages"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
  ]
)
