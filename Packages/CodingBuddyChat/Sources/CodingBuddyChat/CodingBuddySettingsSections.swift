import SwiftUI

struct CodingBuddySettingsSections: View {
  @Bindable var interviewSettings: BuddyInterviewSettings
  let voiceController: CodingBuddyVoiceController?

  var body: some View {
    Group {
      InterviewSettingsSection(settings: interviewSettings)
      if let voiceController {
        CodingBuddyVoiceSettingsSections(controller: voiceController)
      }
    }
  }
}
