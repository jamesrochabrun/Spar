//
//  InterviewSettingsSection.swift
//  CodingBuddyChat
//
//  "Interview" section injected into the settings Form: picks the
//  specialization track that steers question generation in every mode.
//

import InterviewKit
import SwiftUI

struct InterviewSettingsSection: View {
  @Bindable var settings: BuddyInterviewSettings

  var body: some View {
    Section {
      Picker(selection: $settings.specialization) {
        ForEach(InterviewSpecialization.allCases) { specialization in
          Label(specialization.displayName, systemImage: specialization.systemImage)
            .tag(specialization)
        }
      } label: {
        Text("Specialization")
      }

      Text(settings.specialization.summary)
        .font(.caption)
        .foregroundStyle(.secondary)
    } header: {
      Text("Interview")
    } footer: {
      Text("Applies to new sessions in every mode.")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }
}
