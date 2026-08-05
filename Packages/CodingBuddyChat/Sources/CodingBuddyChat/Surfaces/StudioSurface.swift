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
  case workspace   // SourceCodeEditorView over the attempt workspace dir, problem embedded
  case hints       // strategy guidance, hint budget, question recap
  case whiteboard  // MCP app surface (excalidraw)
  case report      // rubric bars, per-dimension comments, improvement notes

  public var id: String { rawValue }

  public var displayName: String {
    switch self {
    case .workspace: return "Workspace"
    case .hints: return "Hints"
    case .whiteboard: return "Whiteboard"
    case .report: return "Report"
    }
  }

  public var systemImage: String {
    switch self {
    case .workspace: return "chevron.left.forwardslash.chevron.right"
    case .hints: return "lightbulb"
    case .whiteboard: return "rectangle.3.group"
    case .report: return "chart.bar.doc.horizontal"
    }
  }

  public static func available(for mode: SessionMode?) -> [StudioSurface] {
    switch mode {
    case .systemDesign:
      return [.whiteboard, .hints, .report]
    case .behavioral:
      return [.hints, .report]
    case .mockInterview, .drill, .practice, nil:
      return [.workspace, .whiteboard, .report]
    }
  }

  public static func defaultSurface(for mode: SessionMode?) -> StudioSurface {
    switch mode {
    case .systemDesign: return .whiteboard
    case .behavioral: return .hints
    default: return .workspace
    }
  }
}
