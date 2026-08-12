import Foundation

public enum CodingBuddyVoiceDefaults {
  private static let keyPrefix = "com.codingbuddy.voice."

  public static let enabled = "\(keyPrefix)enabled"
  public static let autoSubmitDictation = "\(keyPrefix)autoSubmitDictation"
  public static let mode = "\(keyPrefix)mode"
  public static let realtimeModel = "\(keyPrefix)realtimeModel"
  public static let voiceName = "\(keyPrefix)voiceName"
  public static let vadEagerness = "\(keyPrefix)vadEagerness"
  public static let dictationModel = "\(keyPrefix)dictationModel"
  public static let language = "\(keyPrefix)language"
  public static let allowBargeIn = "\(keyPrefix)allowBargeIn"
  public static let hudFrame = "\(keyPrefix)hudFrame"
  public static let screenCaptureEnabled = "\(keyPrefix)screenCaptureEnabled"
  public static let onboardingCompleted = "\(keyPrefix)onboardingCompleted"
  public static let showTranscript = "\(keyPrefix)showTranscript"

  public static func register(in defaults: UserDefaults) {
    defaults.register(defaults: [
      enabled: true,
      autoSubmitDictation: true,
      mode: "dictate",
      realtimeModel: "gpt-realtime",
      voiceName: "marin",
      vadEagerness: "medium",
      dictationModel: "whisper-1",
      language: "auto",
      allowBargeIn: false,
      screenCaptureEnabled: true,
      onboardingCompleted: false,
      showTranscript: false,
    ])
  }
}
