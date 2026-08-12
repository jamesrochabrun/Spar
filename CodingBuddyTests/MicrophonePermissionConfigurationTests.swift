import Foundation
import Testing

struct MicrophonePermissionConfigurationTests {
  @Test
  func appHasStableSigningIdentityForPrivacyAuthorization() throws {
    let projectSource = try sourceContents("CodingBuddy.xcodeproj/project.pbxproj")
    let appConfigurations = projectSource.components(
      separatedBy: "PRODUCT_BUNDLE_IDENTIFIER = jamesrochabrun.CodingBuddy;"
    )

    #expect(appConfigurations.count == 3)
    for configuration in appConfigurations.dropLast() {
      let buildSettings = configuration.suffix(1_500)
      #expect(buildSettings.contains("DEVELOPMENT_TEAM = CQ45U4X9K3;"))
      #expect(buildSettings.contains("CODE_SIGN_STYLE = Automatic;"))
    }
  }

  @Test
  func appDeclaresMicrophoneUsageDescription() throws {
    let infoPlistData = try Data(
      contentsOf: repositoryRoot.appendingPathComponent("Config/CodingBuddyInfo.plist")
    )
    let infoPlist = try #require(
      PropertyListSerialization.propertyList(from: infoPlistData, format: nil)
        as? [String: Any]
    )

    let description = try #require(
      infoPlist["NSMicrophoneUsageDescription"] as? String
    )
    #expect(!description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
  }

  private func sourceContents(_ relativePath: String) throws -> String {
    try String(
      contentsOf: repositoryRoot.appendingPathComponent(relativePath),
      encoding: .utf8
    )
  }

  private var repositoryRoot: URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
  }
}
