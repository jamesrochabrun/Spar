import Foundation
import Testing
@testable import CodingBuddyChat

struct SessionFocusBindingStoreTests {

  private func makeStore() -> (FileSessionFocusBindingStore, URL) {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("focus-bindings-\(UUID().uuidString).json")
    return (FileSessionFocusBindingStore(fileURL: url), url)
  }

  @Test
  func returnsNoFocusForAnUnknownSession() {
    let (store, url) = makeStore()
    defer { try? FileManager.default.removeItem(at: url) }

    #expect(store.focus(chatSessionID: "missing") == nil)
  }

  @Test
  func roundTripsBindingsPerSession() {
    let (store, url) = makeStore()
    defer { try? FileManager.default.removeItem(at: url) }

    store.save(focus: "Design a ride-sharing dispatch system", chatSessionID: "session-a")
    store.save(focus: "Drill Swift concurrency", chatSessionID: "session-b")

    #expect(store.focus(chatSessionID: "session-a") == "Design a ride-sharing dispatch system")
    #expect(store.focus(chatSessionID: "session-b") == "Drill Swift concurrency")
  }

  @Test
  func savingNilOrEmptyClearsTheBinding() {
    let (store, url) = makeStore()
    defer { try? FileManager.default.removeItem(at: url) }

    store.save(focus: "Drill Swift concurrency", chatSessionID: "session-a")
    store.save(focus: nil, chatSessionID: "session-a")
    #expect(store.focus(chatSessionID: "session-a") == nil)

    store.save(focus: "Drill Swift concurrency", chatSessionID: "session-a")
    store.save(focus: "", chatSessionID: "session-a")
    #expect(store.focus(chatSessionID: "session-a") == nil)
  }

  @Test
  func deleteRemovesOnlyTheNamedSession() {
    let (store, url) = makeStore()
    defer { try? FileManager.default.removeItem(at: url) }

    store.save(focus: "System design", chatSessionID: "session-a")
    store.save(focus: "Behavioral themes", chatSessionID: "session-b")
    store.delete(chatSessionID: "session-a")

    #expect(store.focus(chatSessionID: "session-a") == nil)
    #expect(store.focus(chatSessionID: "session-b") == "Behavioral themes")
  }
}
