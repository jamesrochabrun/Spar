import AgentHubVoice
import Foundation
import Testing
@testable import CodingBuddyChat

@MainActor
struct CodingBuddyVoiceControlCoordinatorTests {
  @Test
  func usesCommandOptionVAndHonorsTheEnabledPreference() {
    #expect(GlobalHotKey.voiceHUDDefault.displayString == "⌘⌥V")

    let defaults = makeDefaults()
    defaults.set(false, forKey: CodingBuddyVoiceDefaults.enabled)
    let registrar = MockRegistrar()
    let presenter = MockPresenter()
    let coordinator = CodingBuddyVoiceControlCoordinator(
      registrar: registrar,
      presenter: presenter,
      defaults: defaults
    )

    coordinator.start()
    #expect(registrar.registered.isEmpty)

    coordinator.setEnabled(true)
    #expect(registrar.registered == [.voiceHUDDefault])

    registrar.fire()
    #expect(presenter.isVisible)
    registrar.fire()
    #expect(!presenter.isVisible)
  }

  @Test
  func surfacesRegistrationFailures() {
    let defaults = makeDefaults()
    defaults.set(true, forKey: CodingBuddyVoiceDefaults.enabled)
    let registrar = MockRegistrar()
    registrar.error = GlobalHotKeyRegistrationError.registerFailed(status: -42)
    let coordinator = CodingBuddyVoiceControlCoordinator(
      registrar: registrar,
      presenter: MockPresenter(),
      defaults: defaults
    )

    coordinator.start()

    #expect(coordinator.registrationErrorMessage?.contains("-42") == true)
  }

  private func makeDefaults() -> UserDefaults {
    let suite = "CodingBuddyVoiceControlCoordinatorTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite) ?? .standard
    defaults.removePersistentDomain(forName: suite)
    return defaults
  }

  @MainActor
  private final class MockRegistrar: GlobalHotKeyRegistrarProtocol {
    var onHotKeyPressed: (@MainActor @Sendable () -> Void)?
    var onHotKeyReleased: (@MainActor @Sendable () -> Void)?
    var registered: [GlobalHotKey] = []
    var error: Error?

    var isRegistered: Bool { !registered.isEmpty }

    func register(hotKey: GlobalHotKey) throws {
      if let error { throw error }
      registered.append(hotKey)
    }

    func unregister() {
      registered.removeAll()
    }

    func fire() {
      onHotKeyPressed?()
    }
  }

  @MainActor
  private final class MockPresenter: VoiceHUDPresenting {
    var isVisible = false

    func show() {
      isVisible = true
    }

    func hide() {
      isVisible = false
    }
  }
}
