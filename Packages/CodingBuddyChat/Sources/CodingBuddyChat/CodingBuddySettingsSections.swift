import SwiftUI

struct CodingBuddySettingsSections: View {
  @Bindable var interviewSettings: BuddyInterviewSettings
  @Bindable var ruleLibrary: FileRuleLibrary
  let voiceController: CodingBuddyVoiceController?

  var body: some View {
    Group {
      InterviewSettingsSection(settings: interviewSettings, ruleLibrary: ruleLibrary)
      if let voiceController {
        CodingBuddyVoiceSettingsSections(controller: voiceController)
      }
    }
  }
}
