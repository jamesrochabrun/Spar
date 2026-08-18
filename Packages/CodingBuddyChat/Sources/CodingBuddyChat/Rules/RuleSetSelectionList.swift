//
//  RuleSetSelectionList.swift
//  CodingBuddyChat
//
//  The rules checklist, shared by the New Session sheet (what this session runs
//  under) and Settings (what every new session starts pre-checked with).
//

import CodingBuddyKit
import SwiftUI

struct RuleSetSelectionList: View {

  @Bindable var library: FileRuleLibrary
  @Binding var selectedIDs: Set<String>
  /// Settings manages defaults only; the session sheet also imports and deletes.
  var allowsManagement: Bool = true
  var onAddRules: (() -> Void)?

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      if library.ruleSets.isEmpty {
        emptyState
      } else {
        VStack(spacing: 0) {
          ForEach(library.ruleSets) { ruleSet in
            row(for: ruleSet)
          }
        }
        .background(
          EaselDesignSystem.Palette.subtleSurface(for: colorScheme),
          in: RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.control)
        )
      }

      if let errorMessage = library.errorMessage {
        Label(errorMessage, systemImage: "exclamationmark.triangle")
          .font(.callout)
          .foregroundStyle(EaselDesignSystem.Palette.danger)
      }
    }
  }

  private func row(for ruleSet: RuleSet) -> some View {
    Toggle(isOn: binding(for: ruleSet.id)) {
      Text(ruleSet.name)
        .font(.callout)
        .foregroundStyle(.primary)
        .lineLimit(1)
        .truncationMode(.middle)
    }
    .toggleStyle(.checkbox)
    .padding(.horizontal, 12)
    .padding(.vertical, 7)
    .frame(maxWidth: .infinity, alignment: .leading)
    .contentShape(Rectangle())
    .contextMenu {
      Button("Reveal in Finder") { library.revealInFinder(ruleSet) }
      if allowsManagement {
        Button("Delete", role: .destructive) {
          selectedIDs.remove(ruleSet.id)
          library.delete(ruleSet)
        }
      }
    }
  }

  private var emptyState: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("No rules yet.")
        .font(.callout)
        .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))

      Text("Add a Markdown file of engineering rules — a house style, an architecture bar, a review checklist. \(AppBrand.name) keeps them in \(FileRuleLibrary.displayPath).")
        .font(.callout)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      if let onAddRules {
        Button("Add Rules", systemImage: "doc.badge.plus", action: onAddRules)
          .controlSize(.small)
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      EaselDesignSystem.Palette.subtleSurface(for: colorScheme),
      in: RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.control)
    )
  }

  private func binding(for id: String) -> Binding<Bool> {
    Binding(
      get: { selectedIDs.contains(id) },
      set: { isOn in
        if isOn {
          selectedIDs.insert(id)
        } else {
          selectedIDs.remove(id)
        }
      }
    )
  }
}
