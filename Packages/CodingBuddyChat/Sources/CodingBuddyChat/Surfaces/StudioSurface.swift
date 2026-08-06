//
//  StudioSurface.swift
//  CodingBuddyChat
//

import Foundation
import InterviewKit

/// Right-panel surfaces. Availability and the default surface derive from the
/// active session's mode. Coding modes default to the workspace (the problem
/// statement is embedded there) and expose hints from a floating editor
/// popover. Non-coding modes can still use the dedicated hints surface.
public enum StudioSurface: String, CaseIterable, Identifiable {
  case sources     // read-only passages retrieved from an active Study Space
  case workspace   // SourceCodeEditorView over the attempt workspace dir, problem embedded
  case hints       // strategy guidance, hint budget, question recap
  case whiteboard  // MCP app surface (excalidraw)
  case report      // rubric bars, per-dimension comments, improvement notes

  public var id: String { rawValue }

  public var displayName: String {
    switch self {
    case .sources: return "Sources"
    case .workspace: return "Workspace"
    case .hints: return "Hints"
    case .whiteboard: return "Whiteboard"
    case .report: return "Report"
    }
  }

  public var systemImage: String {
    switch self {
    case .sources: return "books.vertical"
    case .workspace: return "chevron.left.forwardslash.chevron.right"
    case .hints: return "lightbulb"
    case .whiteboard: return "rectangle.3.group"
    case .report: return "chart.bar.doc.horizontal"
    }
  }

  public static func available(
    for mode: SessionMode?,
    includesSources: Bool = false
  ) -> [StudioSurface] {
    let modeSurfaces: [StudioSurface]
    switch mode {
    case .systemDesign:
      modeSurfaces = [.whiteboard, .hints, .report]
    case .behavioral:
      modeSurfaces = [.hints, .report]
    case .mockInterview, .drill, .practice, nil:
      modeSurfaces = [.workspace, .whiteboard, .report]
    }
    guard includesSources else { return modeSurfaces }
    // Sources is a reference surface, never the primary one: it slots in
    // right after the mode's main working surface.
    return Array(modeSurfaces.prefix(1)) + [.sources] + modeSurfaces.dropFirst()
  }

  /// Sessions always open on the mode's working surface (workspace for coding
  /// modes) — grounded sessions reach Sources via the tab or a citation click.
  public static func defaultSurface(for mode: SessionMode?) -> StudioSurface {
    switch mode {
    case .systemDesign: return .whiteboard
    case .behavioral: return .hints
    default: return .workspace
    }
  }
}
