import AgentHubVoice
import AgentHubVoicePanel
import Foundation
import Observation

@Observable
@MainActor
public final class CodingBuddyVoiceController {
  public let engine: RealtimeVoiceEngine
  public let keyProvider: any OpenAIKeyProviding
  public let viewModel: VoiceHUDViewModel

  public private(set) var isEnabled: Bool
  public private(set) var onboardingPresentationRequest = 0

  @ObservationIgnored private let defaults: UserDefaults
  @ObservationIgnored private let host: CodingBuddyVoiceHUDHost

  public init(
    session: any CodingBuddyVoiceSessionProviding,
    defaults: UserDefaults = .standard,
    engine: RealtimeVoiceEngine? = nil,
    keyProvider: (any OpenAIKeyProviding)? = nil,
    screenCapture: any VoiceScreenCapturing = VoiceScreenCaptureService()
  ) {
    CodingBuddyVoiceDefaults.register(in: defaults)
    let resolvedEngine = engine ?? RealtimeVoiceEngine()
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

    self.defaults = defaults
    self.host = host
    self.isEnabled = defaults.bool(forKey: CodingBuddyVoiceDefaults.enabled)
    self.engine = resolvedEngine
    self.keyProvider = resolvedKeyProvider
    viewModel = VoiceHUDViewModel(
      host: host,
      engine: resolvedEngine,
      configuration: .codingBuddy,
      defaults: defaults
    )
  }

  public var isSessionAvailable: Bool {
    host.resolveTarget(manualId: nil) != nil
  }

  public var canUseVoice: Bool {
    isEnabled && isSessionAvailable
  }

  public var conversationStatus: CodingBuddyVoiceConversationStatus {
    CodingBuddyVoiceConversationStatus(
      isEnabled: isEnabled,
      isSessionAvailable: isSessionAvailable,
      mode: viewModel.mode,
      realtimeState: viewModel.realtimeState,
      isMicrophoneMuted: viewModel.isMicrophoneMuted,
      isMicrophoneGated: viewModel.isMicrophoneGated,
      isMicrophoneStandbyMuted: viewModel.isMicrophoneStandbyMuted
    )
  }

  public var conversationTranscripts: [VoiceTranscriptEntry] {
    viewModel.sessionConversationTranscripts
  }

  public var errorMessage: String? {
    viewModel.errorMessage
  }

  public var shouldAutomaticallyShowTranscript: Bool {
    defaults.bool(forKey: CodingBuddyVoiceDefaults.showTranscript)
  }

  public var requiresOnboarding: Bool {
    !defaults.bool(forKey: CodingBuddyVoiceDefaults.onboardingCompleted)
  }

  public func requestConversationToggle() {
    guard canUseVoice else { return }
    if conversationStatus.isActive {
      toggleConversation()
    } else if requiresOnboarding {
      onboardingPresentationRequest += 1
    } else {
      toggleConversation()
    }
  }

  public func toggleConversation() {
    guard canUseVoice else { return }
    activate(mode: .converse)
  }

  public func toggleDictation() {
    guard canUseVoice else { return }
    activate(mode: .dictate)
  }

  public func toggleMicrophoneMute() {
    viewModel.toggleMicrophoneMute()
  }

  public func handleSessionChange() {
    viewModel.resetForTargetChange()
  }

  public func stop() {
    viewModel.stopAllAudio()
  }

  public func setEnabled(_ enabled: Bool) {
    defaults.set(enabled, forKey: CodingBuddyVoiceDefaults.enabled)
    isEnabled = enabled
    if !enabled {
      stop()
    }
  }

  private func activate(mode: VoiceHUDMode) {
    if viewModel.mode != mode {
      viewModel.mode = mode
      viewModel.handleModeChange()
    }
    viewModel.toggleMicrophone()
  }
}
