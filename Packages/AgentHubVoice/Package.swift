// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "AgentHubVoice",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .library(
      name: "AgentHubVoice",
      targets: ["AgentHubVoice"]
    ),
    .library(
      name: "AgentHubVoicePanel",
      targets: ["AgentHubVoicePanel"]
    ),
  ],
  dependencies: [
    // 4.6.0 carries the AudioPCMPlayer dead-IO play() crash fix (PR #197, commit 3db60ad).
    .package(
      url: "https://github.com/jamesrochabrun/SwiftOpenAI.git",
      exact: "4.6.0"
    )
  ],
  targets: [
    .target(
      name: "AgentHubVoice",
      dependencies: [
        .product(name: "SwiftOpenAI", package: "SwiftOpenAI")
      ],
      path: "Sources/AgentHubVoice",
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
    .target(
      name: "AgentHubVoicePanel",
      dependencies: ["AgentHubVoice"],
      path: "Sources/AgentHubVoicePanel",
      resources: [
        .process("Shaders")
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
    .testTarget(
      name: "AgentHubVoiceTests",
      dependencies: ["AgentHubVoice"],
      path: "Tests/AgentHubVoiceTests",
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
    .testTarget(
      name: "AgentHubVoicePanelTests",
      dependencies: ["AgentHubVoicePanel"],
      path: "Tests/AgentHubVoicePanelTests",
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    )
  ]
)
