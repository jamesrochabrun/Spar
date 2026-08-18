//
//  InterviewSettingsSection.swift
//  CodingBuddyChat
//
//  "Interview" section injected into the settings Form: picks the
//  specialization track that steers question generation in every mode, and the
//  house-rule sets every new session starts pre-checked with.
//

import CodingBuddyKit
import InterviewKit
import SwiftUI

struct InterviewSettingsSection: View {
  @Bindable var settings: BuddyInterviewSettings
  @Bindable var ruleLibrary: FileRuleLibrary

  @State private var defaultRuleSelection: Set<String> = []

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

    Section {
      RuleSetSelectionList(
        library: ruleLibrary,
        selectedIDs: $defaultRuleSelection,
        allowsManagement: false
      )

      Button("Open Rules Folder", systemImage: "folder") {
        ruleLibrary.revealFolderInFinder()
      }
      .controlSize(.small)
      .easelSecondaryButton()
    } header: {
      Text("Default Rules")
    } footer: {
      Text("Checked rules are pre-selected for every new session; you can still change the selection per session. Drop Markdown files into \(FileRuleLibrary.displayPath) to add more.")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .task {
      ruleLibrary.load()
      defaultRuleSelection = Set(settings.defaultRuleSetIDs)
    }
    .onChange(of: defaultRuleSelection) { _, selection in
      // Store in library order so Settings and the session sheet agree.
      settings.defaultRuleSetIDs = ruleLibrary.ruleSets
        .map(\.id)
        .filter(selection.contains)
    }
  }
}
