import Foundation
import Testing
@testable import CodingBuddyChat

struct SessionRuleBindingStoreTests {

  private func makeStore() -> (FileSessionRuleBindingStore, URL) {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("rule-bindings-\(UUID().uuidString).json")
    return (FileSessionRuleBindingStore(fileURL: url), url)
  }

  @Test
  func returnsNoRulesForAnUnknownSession() {
    let (store, url) = makeStore()
    defer { try? FileManager.default.removeItem(at: url) }

    #expect(store.ruleSetIDs(chatSessionID: "missing").isEmpty)
  }

  @Test
  func roundTripsBindingsPerSession() {
    let (store, url) = makeStore()
    defer { try? FileManager.default.removeItem(at: url) }

    store.save(ruleSetIDs: ["style", "review"], chatSessionID: "session-a")
    store.save(ruleSetIDs: ["style"], chatSessionID: "session-b")

    #expect(store.ruleSetIDs(chatSessionID: "session-a") == ["style", "review"])
    #expect(store.ruleSetIDs(chatSessionID: "session-b") == ["style"])
  }

  @Test
  func savingAnEmptySelectionClearsTheBinding() {
    let (store, url) = makeStore()
    defer { try? FileManager.default.removeItem(at: url) }

    store.save(ruleSetIDs: ["style"], chatSessionID: "session-a")
    store.save(ruleSetIDs: [], chatSessionID: "session-a")

    #expect(store.ruleSetIDs(chatSessionID: "session-a").isEmpty)
  }

  @Test
  func deleteRemovesOnlyTheNamedSession() {
    let (store, url) = makeStore()
    defer { try? FileManager.default.removeItem(at: url) }

    store.save(ruleSetIDs: ["style"], chatSessionID: "session-a")
    store.save(ruleSetIDs: ["review"], chatSessionID: "session-b")
    store.delete(chatSessionID: "session-a")

    #expect(store.ruleSetIDs(chatSessionID: "session-a").isEmpty)
    #expect(store.ruleSetIDs(chatSessionID: "session-b") == ["review"])
  }
}
