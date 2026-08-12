import AgentHubVoice
import CodingBuddyKit
import Foundation

@MainActor
final class CodingBuddyVoiceToolCatalog {
  private weak var session: (any CodingBuddyVoiceSessionProviding)?
  private let engine: RealtimeVoiceEngine
  private let screenCapture: any VoiceScreenCapturing
  private let workspaceReader: any CodingBuddyVoiceWorkspaceReading
  private let defaults: UserDefaults

  init(
    session: any CodingBuddyVoiceSessionProviding,
    engine: RealtimeVoiceEngine,
    screenCapture: any VoiceScreenCapturing = VoiceScreenCaptureService(),
    workspaceReader: any CodingBuddyVoiceWorkspaceReading = CodingBuddyVoiceWorkspaceReader(),
    defaults: UserDefaults = .standard
  ) {
    self.session = session
    self.engine = engine
    self.screenCapture = screenCapture
    self.workspaceReader = workspaceReader
    self.defaults = defaults
  }

  func makeTools() -> [VoiceTool] {
    var tools = [
      listSessionsTool(),
      sessionStatusTool(),
      readResponseTool(),
      readHistoryTool(),
      listWorkspaceFilesTool(),
      readWorkspaceFileTool(),
    ]
    if isScreenCaptureEnabled {
      tools.append(
        contentsOf: VoiceScreenCaptureTools.make(
          capture: screenCapture,
          isEnabled: { [weak self] in self?.isScreenCaptureEnabled == true },
          onCaptured: { [weak self] capture in
            try await self?.engine.stageImageForNextToolResponse(
              at: capture.path,
              context: "Screenshot captured from \(capture.display.name)."
            )
          }
        )
      )
    }
    return tools
  }

  private var isScreenCaptureEnabled: Bool {
    defaults.bool(forKey: CodingBuddyVoiceDefaults.screenCaptureEnabled)
  }

  private func listSessionsTool() -> VoiceTool {
    VoiceTool(
      name: "list_sessions",
      description: """
        Return \(AppBrand.name)'s currently selected chat session. The target ID is
        stable while the user switches sessions, so every voice prompt stays
        synchronized with the chat that is visible in the app.
        """,
      parameters: objectSchema(properties: [:])
    ) { [weak self] _ in
      guard let snapshot = self?.session?.voiceSessionSnapshot else {
        return Self.encode(
          BasicResult(status: "unavailable", message: "No chat session is ready.")
        )
      }
      return Self.encode(
        SessionListResult(sessions: [snapshot], targetSessionId: snapshot.id)
      )
    }
  }

  private func sessionStatusTool() -> VoiceTool {
    VoiceTool(
      name: "get_session_status",
      description: "Read the current interview mode, problem, provider, and chat status.",
      parameters: objectSchema(
        properties: [
          "session_id": [
            "type": "string",
            "description": "Exact ID returned by list_sessions.",
          ],
        ],
        required: ["session_id"]
      )
    ) { [weak self] data in
      guard let arguments = Self.decode(SessionArguments.self, from: data),
            let snapshot = self?.session?.voiceSessionSnapshot,
            snapshot.id == arguments.sessionId else {
        return Self.notFoundJSON
      }
      return Self.encode(snapshot)
    }
  }

  private func readResponseTool() -> VoiceTool {
    VoiceTool(
      name: "read_session_response",
      description: """
        Read the latest response from the active \(AppBrand.name) chat agent. Use
        its actual content when answering; never invent a result or tell the
        user to look at the chat instead.
        """,
      parameters: objectSchema(
        properties: [
          "session_id": [
            "type": "string",
            "description": "Exact ID returned by list_sessions.",
          ],
        ]
      )
    ) { [weak self] data in
      let arguments = Self.decode(OptionalSessionArguments.self, from: data)
      guard self?.matchesTarget(arguments?.sessionId) == true,
            let response = self?.session?.voiceLatestResponse else {
        return Self.encode(
          BasicResult(status: "not_found", message: "There is no completed response yet.")
        )
      }
      return Self.encode(ResponseResult(status: "ok", text: response))
    }
  }

  private func readHistoryTool() -> VoiceTool {
    VoiceTool(
      name: "read_session_history",
      description: """
        Read recent user and assistant turns from the active \(AppBrand.name) chat.
        Use this for earlier context; use read_session_response for only the
        latest completed answer.
        """,
      parameters: objectSchema(
        properties: [
          "session_id": [
            "type": "string",
            "description": "Exact ID returned by list_sessions.",
          ],
          "turn_limit": [
            "type": "integer",
            "minimum": 1,
            "maximum": 20,
            "description": "Maximum turns to return. Defaults to 8.",
          ],
        ]
      )
    ) { [weak self] data in
      let arguments = Self.decode(HistoryArguments.self, from: data)
      guard self?.matchesTarget(arguments?.sessionId) == true,
            let snapshot = self?.session?.voiceSessionSnapshot else {
        return Self.notFoundJSON
      }
      let limit = min(20, max(1, arguments?.turnLimit ?? 8))
      return Self.encode(
        HistoryResult(
          status: "ok",
          sessionId: snapshot.id,
          turns: Array(snapshot.recentTurns.suffix(limit))
        )
      )
    }
  }

  private func listWorkspaceFilesTool() -> VoiceTool {
    VoiceTool(
      name: "list_workspace_files",
      description: """
        Read the contents of a directory inside the active attempt workspace.
        This tool is read-only. Use paths relative to the workspace root and
        call it to understand the user's current implementation progress.
        """,
      parameters: objectSchema(
        properties: [
          "session_id": [
            "type": "string",
            "description": "Exact ID returned by list_sessions.",
          ],
          "path": [
            "type": "string",
            "description": "Relative directory path. Omit for the workspace root.",
          ],
        ],
        required: ["session_id"]
      )
    ) { [weak self] data in
      guard let self,
            let arguments = Self.decode(WorkspaceListArguments.self, from: data),
            matchesTarget(arguments.sessionId),
            let snapshot = session?.voiceSessionSnapshot else {
        return Self.notFoundJSON
      }
      guard let workspacePath = snapshot.workspacePath else {
        return Self.encode(
          BasicResult(
            status: "unavailable",
            message: "The active session does not have an attempt workspace."
          )
        )
      }

      do {
        let entries = try await workspaceReader.listEntries(
          in: workspacePath,
          relativePath: arguments.path
        )
        return Self.encode(
          WorkspaceListResult(
            status: "ok",
            workspacePath: workspacePath,
            directory: arguments.path ?? ".",
            entries: entries
          )
        )
      } catch {
        return Self.encode(
          BasicResult(status: "error", message: error.localizedDescription)
        )
      }
    }
  }

  private func readWorkspaceFileTool() -> VoiceTool {
    VoiceTool(
      name: "read_workspace_file",
      description: """
        Read a UTF-8 text file inside the active attempt workspace. This tool
        is read-only and cannot access paths outside that workspace.
        """,
      parameters: objectSchema(
        properties: [
          "session_id": [
            "type": "string",
            "description": "Exact ID returned by list_sessions.",
          ],
          "path": [
            "type": "string",
            "description": "File path relative to the workspace root.",
          ],
          "max_characters": [
            "type": "integer",
            "minimum": 1_000,
            "maximum": 20_000,
            "description": "Maximum returned characters. Defaults to 12,000.",
          ],
        ],
        required: ["session_id", "path"]
      )
    ) { [weak self] data in
      guard let self,
            let arguments = Self.decode(WorkspaceReadArguments.self, from: data),
            matchesTarget(arguments.sessionId),
            let workspacePath = session?.voiceSessionSnapshot?.workspacePath else {
        return Self.notFoundJSON
      }

      do {
        let content = try await workspaceReader.readFile(
          in: workspacePath,
          relativePath: arguments.path,
          characterLimit: arguments.maxCharacters ?? 12_000
        )
        return Self.encode(
          WorkspaceFileResult(
            status: "ok",
            path: arguments.path,
            content: content
          )
        )
      } catch {
        return Self.encode(
          BasicResult(status: "error", message: error.localizedDescription)
        )
      }
    }
  }

  private func matchesTarget(_ requestedID: String?) -> Bool {
    guard let targetID = session?.voiceSessionSnapshot?.id else { return false }
    return requestedID == nil || requestedID == targetID
  }

  private func objectSchema(
    properties: [String: VoiceJSONValue],
    required: [String] = []
  ) -> [String: VoiceJSONValue] {
    var schema: [String: VoiceJSONValue] = [
      "type": "object",
      "properties": .object(properties),
      "additionalProperties": false,
    ]
    if !required.isEmpty {
      schema["required"] = .array(required.map(VoiceJSONValue.string))
    }
    return schema
  }

  private static func decode<T: Decodable>(
    _ type: T.Type,
    from data: Data
  ) -> T? {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return try? decoder.decode(type, from: data)
  }

  private static func encode<T: Encodable>(_ value: T) -> String {
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    encoder.outputFormatting = [.sortedKeys]
    guard let data = try? encoder.encode(value) else { return unavailableJSON }
    return String(decoding: data, as: UTF8.self)
  }

  private static let unavailableJSON =
    #"{"status":"error","message":"Voice tools are unavailable."}"#
  private static let notFoundJSON =
    #"{"status":"not_found","message":"The active chat session was not found."}"#

  private struct SessionArguments: Decodable {
    let sessionId: String
  }

  private struct OptionalSessionArguments: Decodable {
    let sessionId: String?
  }

  private struct HistoryArguments: Decodable {
    let sessionId: String?
    let turnLimit: Int?
  }

  private struct WorkspaceListArguments: Decodable {
    let sessionId: String
    let path: String?
  }

  private struct WorkspaceReadArguments: Decodable {
    let sessionId: String
    let path: String
    let maxCharacters: Int?
  }

  private struct SessionListResult: Encodable {
    let sessions: [CodingBuddyVoiceSessionSnapshot]
    let targetSessionId: String
  }

  private struct ResponseResult: Encodable {
    let status: String
    let text: String
  }

  private struct HistoryResult: Encodable {
    let status: String
    let sessionId: String
    let turns: [CodingBuddyVoiceTurn]
  }

  private struct WorkspaceListResult: Encodable {
    let status: String
    let workspacePath: String
    let directory: String
    let entries: [CodingBuddyVoiceWorkspaceEntry]
  }

  private struct WorkspaceFileResult: Encodable {
    let status: String
    let path: String
    let content: String
  }

  private struct BasicResult: Encodable {
    let status: String
    let message: String?
  }
}
