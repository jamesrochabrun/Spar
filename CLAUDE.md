# CodingBuddy — Project Instructions

## What this app is

CodingBuddy is a macOS interview-prep app: an AI interviewer (5 session modes — mock interview, drills, practice, system design, behavioral) that presents questions, enforces a hint budget, and grades attempts against per-mode rubrics. Questions and evaluations persist to a local SQLite question bank; a dashboard tracks per-topic skill.

## AI Providers

Three interchangeable providers — **Claude** (Claude Code CLI), **Codex** (Codex CLI), and **Local/API** (Ollama / LM Studio / OpenAI-compatible / on-device MLX) — selectable per session. Auth is delegated to the underlying CLI (no API keys). When working on provider, chat, or runtime code, keep all providers working and avoid provider-specific assumptions in shared layers.

## Structured-output contracts

The agent emits fenced JSON blocks in the transcript that the app parses (`InterviewKit/Parsing`):

- ```` ```buddy-question ```` — `{"schema":"buddy-question/v1", title, difficulty, topics, prompt_markdown, reference_notes, language_hint}` → saved to the question bank.
- ```` ```buddy-eval ```` — `{"schema":"buddy-eval/v1", overall_score, verdict, dimensions, summary_markdown, improvement_notes}` → persisted as the attempt's evaluation.

The contracts live verbatim in `BuddyAgentInstructions.swift` and the parser fixture tests. Keep prompts, parsers, and tests in sync when changing them.

## Architecture map

- `CodingBuddy/` — thin AppKit shell: `MainContentView` (sidebar | chat | surface panel), window/panel management.
- `Packages/InterviewKit` — domain models, `InterviewSQLiteStorage` (interview_bank.sqlite), `InterviewSessionService`, `SessionTimer`, structured-block parsers. Depends only on SQLite.swift; the chat session id crosses the seam as a plain `String`.
- `Packages/CodingBuddyChat` — `ChatService` (per-session ChatViewModel+DependencyContainer cache — keep this design), `BuddyAgentInstructions`, sidebar, surfaces (problem/workspace/whiteboard/report), dashboard, `MCPAppSessionService`.
- `Packages/CodingBuddyClaudeCodeUI` (module **ClaudeCodeCore**) — the chat engine: view models, stream processing, SQLite session storage, permissions, MCP config.
- `Packages/BuddyMCPUI` — MCP Apps host (WKWebView JSON-RPC bridge, MCP clients, side panel), ported from AgentHub.
- The MCP config the agent session uses and the app-side resolver read the same file: `~/.config/claude/mcp-config.json`.

## Framework

- Use **SwiftUI** exclusively for all UI code — no UIKit or AppKit unless absolutely necessary
- Prefer declarative patterns over imperative ones

## Concurrency

- Use **modern Swift concurrency** (`async/await`, `Task`, actors, `AsyncSequence`)
- **Never use GCD** (`DispatchQueue`, `DispatchGroup`, etc.)

## State Management

- Use the **`@Observable`** macro for observable state — never `ObservableObject` or `@Published`
- Use `@State`, `@Environment`, and `@Bindable` for SwiftUI view state

## Architecture rules

- Define all services as **protocol interfaces** so dependencies can be injected and easily mocked/stubbed in tests
- Use **dependency injection** — no singletons or global shared state
- Keep the project **modular**: each feature should live in its own Swift package/module when applicable
- Separate concerns: views, view models, services, and models should be in distinct layers

## Local Persistence

- Attempt workspaces live under `~/Documents/CodingBuddy/Workspaces/` — user-visible and independent of the app install
- Databases live under `~/Library/Application Support/CodingBuddy/` (`interview_bank.sqlite` is owned by InterviewKit's migration manager; `claude_code_sessions.sqlite` by ClaudeCodeCore's — never mix their schemas)
- The only cross-DB relation is `attempts.chat_session_id`, a soft TEXT link tolerating independent deletion

## Testing

- **Always write unit tests** for new code
- Leverage protocol interfaces to create mocks/stubs for testing
- App-level tests in `CodingBuddyTests`/`CodingBuddyUITests`; package tests in each package's `Tests/`
- Note: run package tests via `xcodebuild test` for `CodingBuddyChat` (a transitive dep breaks bare `swift test`); `swift test` works for `InterviewKit` and `BuddyMCPUI`

## Skills

When working on this project, always use the following skills when applicable:

- `/swiftui-pro` — for reviewing and writing SwiftUI code with best practices
- `/swiftui-animation` — for implementing animations, transitions, and shader effects
- `/skills:apple-hig-designer` — for designing UI following Apple's Human Interface Guidelines
- `/releasing-macos-apps` — for releasing, notarizing, and distributing macOS apps

## Code Style

- Use **spaces** (not tabs), indent width: **2 spaces**
- Follow Swift API design guidelines for naming
