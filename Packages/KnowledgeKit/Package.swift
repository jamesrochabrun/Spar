// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "KnowledgeKit",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .library(
      name: "KnowledgeKit",
      targets: ["KnowledgeKit"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/stephencelis/SQLite.swift", from: "0.15.3"),
  ],
  targets: [
    .target(
      name: "KnowledgeKit",
      dependencies: [
        .product(name: "SQLite", package: "SQLite.swift"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
    .testTarget(
      name: "KnowledgeKitTests",
      dependencies: ["KnowledgeKit"],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
  ]
)
