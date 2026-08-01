//
//  StudioSurface.swift
//  CodingBuddyChat
//

import Foundation
import InterviewKit

/// Right-panel surfaces. Availability and the default surface derive from the
/// active session's mode.
public enum StudioSurface: String, CaseIterable, Identifiable {
  case problem     // question markdown, difficulty/topic chips, attempt status
  case workspace   // SourceCodeEditorView over the attempt workspace dir
  case whiteboard  // MCP app surface (excalidraw) — WP7
  case report      // rubric bars, per-dimension comments, improvement notes

  public var id: String { rawValue }

  public var displayName: String {
    switch self {
    case .problem: return "Problem"
    case .workspace: return "Workspace"
    case .whiteboard: return "Whiteboard"
    case .report: return "Report"
    }
  }

  public var systemImage: String {
    switch self {
    case .problem: return "doc.text"
    case .workspace: return "chevron.left.forwardslash.chevron.right"
    case .whiteboard: return "rectangle.3.group"
    case .report: return "chart.bar.doc.horizontal"
    }
  }

  public static func available(for mode: SessionMode?) -> [StudioSurface] {
    switch mode {
    case .systemDesign:
      return [.problem, .whiteboard, .report]
    case .behavioral:
      return [.problem, .report]
    case .mockInterview, .drill, .practice, nil:
      return [.problem, .workspace, .whiteboard, .report]
    }
  }

  public static func defaultSurface(for mode: SessionMode?) -> StudioSurface {
    mode == .systemDesign ? .whiteboard : .problem
  }
}
