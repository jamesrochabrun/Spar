import AgentHubVoice
import AgentHubVoicePanel
import Foundation

@MainActor
public final class CodingBuddyVoiceController {
  public let engine: RealtimeVoiceEngine
  public let keyProvider: any OpenAIKeyProviding
  public let controlCoordinator: CodingBuddyVoiceControlCoordinator

  public init(
    session: any CodingBuddyVoiceSessionProviding,
    defaults: UserDefaults = .standard,
    engine: RealtimeVoiceEngine? = nil,
    keyProvider: (any OpenAIKeyProviding)? = nil,
    screenCapture: any VoiceScreenCapturing = VoiceScreenCaptureService(),
    registrar: (any GlobalHotKeyRegistrarProtocol)? = nil
  ) {
    CodingBuddyVoiceDefaults.register(in: defaults)
    let resolvedEngine = engine ?? RealtimeVoiceEngine()
    let resolvedRegistrar = registrar ?? CarbonGlobalHotKeyRegistrar()
    let resolvedKeyProvider = keyProvider ?? OpenAIKeyProvider(
      store: KeychainSecretsStore(service: "com.codingbuddy.secrets")
    )
    let host = CodingBuddyVoiceHUDHost(
      session: session,
      engine: resolvedEngine,
      keyProvider: resolvedKeyProvider,
      screenCapture: screenCapture,
      defaults: defaults
    )
    let presenter = AppKitVoiceHUDPresenter(
      host: host,
      engine: resolvedEngine,
      configuration: .codingBuddy,
      defaults: defaults
    )

    self.engine = resolvedEngine
    self.keyProvider = resolvedKeyProvider
    controlCoordinator = CodingBuddyVoiceControlCoordinator(
      registrar: resolvedRegistrar,
      presenter: presenter,
      defaults: defaults
    )
  }

  public var isHUDVisible: Bool {
    controlCoordinator.isHUDVisible
  }

  public func start() {
    controlCoordinator.start()
  }

  public func stop() {
    controlCoordinator.stop()
  }

  public func showHUD() {
    controlCoordinator.showHUD()
  }

  public func toggleHUD() {
    controlCoordinator.toggleHUD()
  }

  public func setEnabled(_ enabled: Bool) {
    controlCoordinator.setEnabled(enabled)
  }

}
