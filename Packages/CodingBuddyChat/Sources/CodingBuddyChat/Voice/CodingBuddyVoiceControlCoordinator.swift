import AgentHubVoice
import Foundation

@Observable
@MainActor
public final class CodingBuddyVoiceControlCoordinator {
  public private(set) var registrationErrorMessage: String?

  @ObservationIgnored private let registrar: any GlobalHotKeyRegistrarProtocol
  @ObservationIgnored private let presenter: any VoiceHUDPresenting
  @ObservationIgnored private let defaults: UserDefaults
  private let hotKey: GlobalHotKey
  private var isStarted = false

  public var isHUDVisible: Bool {
    presenter.isVisible
  }

  public init(
    registrar: any GlobalHotKeyRegistrarProtocol,
    presenter: any VoiceHUDPresenting,
    defaults: UserDefaults = .standard,
    hotKey: GlobalHotKey = .voiceHUDDefault
  ) {
    self.registrar = registrar
    self.presenter = presenter
    self.defaults = defaults
    self.hotKey = hotKey
  }

  public func start() {
    guard !isStarted else {
      syncHotKeyRegistration()
      return
    }
    isStarted = true
    registrar.onHotKeyPressed = { [weak self] in
      self?.toggleHUD()
    }
    registrar.onHotKeyReleased = nil
    syncHotKeyRegistration()
  }

  public func stop() {
    registrar.unregister()
    registrar.onHotKeyPressed = nil
    registrar.onHotKeyReleased = nil
    presenter.hide()
    isStarted = false
    registrationErrorMessage = nil
  }

  public func setEnabled(_ enabled: Bool) {
    defaults.set(enabled, forKey: CodingBuddyVoiceDefaults.enabled)
    syncHotKeyRegistration()
  }

  public func syncHotKeyRegistration() {
    guard defaults.bool(forKey: CodingBuddyVoiceDefaults.enabled) else {
      registrar.unregister()
      registrationErrorMessage = nil
      return
    }
    do {
      try registrar.register(hotKey: hotKey)
      registrationErrorMessage = nil
    } catch {
      registrar.unregister()
      registrationErrorMessage = error.localizedDescription
    }
  }

  public func showHUD() {
    presenter.show()
  }

  public func toggleHUD() {
    presenter.toggle()
  }
}
