// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "CodingBuddyKit",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .library(
      name: "CodingBuddyKit",
      targets: ["CodingBuddyKit"]
    ),
  ],
  targets: [
    .target(
      name: "CodingBuddyKit",
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
    .testTarget(
      name: "CodingBuddyKitTests",
      dependencies: ["CodingBuddyKit"],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
  ]
)
