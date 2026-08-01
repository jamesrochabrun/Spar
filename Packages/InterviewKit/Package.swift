// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "InterviewKit",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .library(
      name: "InterviewKit",
      targets: ["InterviewKit"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/stephencelis/SQLite.swift", from: "0.15.3"),
  ],
  targets: [
    .target(
      name: "InterviewKit",
      dependencies: [
        .product(name: "SQLite", package: "SQLite.swift"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
    .testTarget(
      name: "InterviewKitTests",
      dependencies: ["InterviewKit"],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
  ]
)
