import AgentHubVoice
import SwiftUI

public struct CodingBuddyVoiceSettingsSections: View {
  private let controller: CodingBuddyVoiceController

  @State private var apiKey = ""
  @State private var keySource: OpenAIKeySource?
  @State private var saveMessage: String?
  @State private var isSaving = false
  @State private var showsOnboarding = false

  @AppStorage(CodingBuddyVoiceDefaults.enabled)
  private var voiceEnabled = true
  @AppStorage(CodingBuddyVoiceDefaults.autoSubmitDictation)
  private var autoSubmitDictation = true
  @AppStorage(CodingBuddyVoiceDefaults.realtimeModel)
  private var realtimeModel = "gpt-realtime"
  @AppStorage(CodingBuddyVoiceDefaults.voiceName)
  private var voiceName = "marin"
  @AppStorage(CodingBuddyVoiceDefaults.vadEagerness)
  private var vadEagerness = "medium"
  @AppStorage(CodingBuddyVoiceDefaults.dictationModel)
  private var dictationModel = "whisper-1"
  @AppStorage(CodingBuddyVoiceDefaults.screenCaptureEnabled)
  private var screenCaptureEnabled = true
  @AppStorage(CodingBuddyVoiceDefaults.language)
  private var language = "auto"
  @AppStorage(CodingBuddyVoiceDefaults.allowBargeIn)
  private var allowBargeIn = false
  @AppStorage(CodingBuddyVoiceDefaults.showTranscript)
  private var showTranscript = false

  public init(controller: CodingBuddyVoiceController) {
    self.controller = controller
  }

  public var body: some View {
    Group {
      CodingBuddyVoiceAPIKeySettingsSection(
        apiKey: $apiKey,
        keySource: keySource,
        saveMessage: saveMessage,
        isSaving: isSaving,
        onSave: saveAPIKey
      )

      CodingBuddyVoiceBehaviorSettingsSection(
        voiceEnabled: $voiceEnabled,
        autoSubmitDictation: $autoSubmitDictation,
        screenCaptureEnabled: $screenCaptureEnabled,
        allowBargeIn: $allowBargeIn,
        showTranscript: $showTranscript,
        onShowOnboarding: showOnboarding
      )

      CodingBuddyVoiceRealtimeSettingsSection(
        realtimeModel: $realtimeModel,
        voiceName: $voiceName,
        vadEagerness: $vadEagerness,
        dictationModel: $dictationModel,
        language: $language
      )
    }
    .task {
      await loadAPIKey()
    }
    .onChange(of: voiceEnabled) { _, enabled in
      controller.setEnabled(enabled)
    }
    .sheet(isPresented: $showsOnboarding) {
      CodingBuddyVoiceOnboardingView(
        onDismiss: dismissOnboarding
      )
    }
  }

  private func showOnboarding() {
    showsOnboarding = true
  }

  private func dismissOnboarding() {
    showsOnboarding = false
  }

  private func loadAPIKey() async {
    do {
      let resolution = try await controller.keyProvider.resolve()
      keySource = resolution?.source
      apiKey = resolution?.source == .keychain ? resolution?.key ?? "" : ""
      saveMessage = nil
    } catch {
      saveMessage = error.localizedDescription
    }
  }

  private func saveAPIKey() {
    isSaving = true
    saveMessage = nil
    Task {
      do {
        try await controller.keyProvider.save(apiKey)
        await loadAPIKey()
        saveMessage = apiKey.isEmpty ? "Stored key removed." : "Saved in Keychain."
      } catch {
        saveMessage = error.localizedDescription
      }
      isSaving = false
    }
  }
}
