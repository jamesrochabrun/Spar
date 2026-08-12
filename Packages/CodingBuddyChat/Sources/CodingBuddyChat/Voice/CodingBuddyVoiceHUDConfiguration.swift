import AgentHubVoice
import CodingBuddyKit

public extension VoiceHUDConfiguration {
  static var codingBuddy: VoiceHUDConfiguration {
    VoiceHUDConfiguration(
      productName: AppBrand.name,
      settings: VoiceHUDSettingsKeys(
        mode: CodingBuddyVoiceDefaults.mode,
        realtimeModel: CodingBuddyVoiceDefaults.realtimeModel,
        voiceName: CodingBuddyVoiceDefaults.voiceName,
        vadEagerness: CodingBuddyVoiceDefaults.vadEagerness,
        dictationModel: CodingBuddyVoiceDefaults.dictationModel,
        language: CodingBuddyVoiceDefaults.language,
        allowBargeIn: CodingBuddyVoiceDefaults.allowBargeIn,
        hudFrame: CodingBuddyVoiceDefaults.hudFrame,
        screenCaptureEnabled: CodingBuddyVoiceDefaults.screenCaptureEnabled,
        onboardingCompleted: CodingBuddyVoiceDefaults.onboardingCompleted,
        showTranscript: CodingBuddyVoiceDefaults.showTranscript
      ),
      accentColor: EaselDesignSystem.Palette.accent
    )
  }
}
