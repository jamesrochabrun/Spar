import SwiftUI
import XCTest
@testable import ClaudeCodeCore

@MainActor
final class ChatComposerVoiceCoachControlTests: XCTestCase {
  func testReadyOrbRendersAsColorInsteadOfAMonochromeTemplate() throws {
    let action = ChatComposerVoiceCoachAction(
      state: .ready,
      title: "Voice Coach",
      detail: nil,
      isEnabled: true,
      isTranscriptPresented: false,
      primaryAction: {},
      muteAction: {},
      endAction: {}
    )
    let renderer = ImageRenderer(
      content: ChatComposerVoiceCoachControl(configuration: action)
        .preferredColorScheme(.dark)
    )
    renderer.scale = 2

    let image = try XCTUnwrap(renderer.nsImage)
    XCTAssertGreaterThan(try saturatedPixelCount(in: image), 100)
  }

  func testVoiceMagicGradientContainsSaturatedColor() throws {
    let violet = try XCTUnwrap(
      NSColor(CodingBuddyChatRuntimeStyle.voiceMagicViolet).usingColorSpace(.sRGB)
    )
    XCTAssertGreaterThan(abs(violet.redComponent - violet.blueComponent), 0.12)

    let renderer = ImageRenderer(
      content: Circle()
        .fill(
          LinearGradient(
            colors: [
              CodingBuddyChatRuntimeStyle.voiceMagicViolet,
              CodingBuddyChatRuntimeStyle.voiceMagicBlue,
              CodingBuddyChatRuntimeStyle.voiceMagicMint,
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
        .frame(width: 30, height: 30)
    )
    renderer.scale = 2

    let image = try XCTUnwrap(renderer.nsImage)
    XCTAssertGreaterThan(try saturatedPixelCount(in: image), 100)
  }

  private func saturatedPixelCount(in image: NSImage) throws -> Int {
    let representation = try XCTUnwrap(image.tiffRepresentation)
    let bitmap = try XCTUnwrap(NSBitmapImageRep(data: representation))
    var saturatedPixelCount = 0

    for y in 0..<bitmap.pixelsHigh {
      for x in 0..<bitmap.pixelsWide {
        guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else {
          continue
        }
        let channels = [color.redComponent, color.greenComponent, color.blueComponent]
        guard let maximum = channels.max(), let minimum = channels.min() else {
          continue
        }
        if maximum - minimum > 0.12, color.alphaComponent > 0.5 {
          saturatedPixelCount += 1
        }
      }
    }
    return saturatedPixelCount
  }
}
