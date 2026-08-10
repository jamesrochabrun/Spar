import Testing
@testable import CodingBuddyKit

struct AppBrandTests {
  @Test
  func publicNameIsSpar() {
    #expect(AppBrand.name == "Spar")
    #expect(AppBrand.symbolName == "scope")
  }
}
