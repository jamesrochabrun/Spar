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

## Interview specialization

`InterviewSpecialization` (InterviewKit, peer of `SessionMode`; default `.iOS`) selects the engineering track for every mode. `SpecializationPromptFactory` (CodingBuddyChat) returns per-(specialization, mode) prompt fragments — full block, compact line for local models, grading addendum — woven in by `BuddyAgentInstructions.prefixes(for:specialization:)` and `evaluationDirective(mode:specialization:)`. The user picks the track in Settings (`InterviewSettingsSection`, persisted by `BuddyInterviewSettings`); `ChatService` reads it when building a session context, so changes apply to the next session. Adding a track = new enum case + factory strings (empty strings mean "no slant", like `.general`).

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

## UI theming and control visibility

- **Every color comes from `EaselDesignSystem.Palette`** (CodingBuddyKit) — never a raw `Color`, a system color like `.blue`, or a hard-coded hex. `Palette.accent` is the app tint and matches the Xcode project's `AccentColor` asset, so the whole app tints from one source.
- **Every control must be clearly legible in both light and dark**, and that does not happen for free here: the tint is a near-black charcoal (`#2E2F2F`) sitting on a near-black dark canvas (`#0D0F0E`). Anything that leans on the default label color — a plain `Button`, a `.bordered` button, an icon-only toolbar control — renders as dim gray on dark gray and effectively disappears.
- Use the **scheme-aware** helpers, not the flat constants, wherever a control needs contrast: `Palette.accentForeground(for:)` for a tinted label, `Palette.surfaceElevated(for:)` / `Palette.subtleSurface(for:)` for a fill, `Palette.border(for:)` for the outline that keeps its edge readable. `Palette.accent` on its own is safe only as a `.borderedProminent` tint, where SwiftUI supplies the contrasting white label.
- Secondary and tertiary actions use **`.easelSecondaryButton()`** (CodingBuddyKit) instead of a bare `.buttonStyle(.bordered)` — it supplies the bordered chrome plus a scheme-aware label color. A test fails the build if a bare `.bordered` button reappears. Anything else that needs a foreground names one from the palette rather than relying on the inherited default.
- Before calling a new or restyled control done, **check it in both color schemes** (`.preferredColorScheme(.dark)` and `.light` in a preview, or the running app), and confirm its disabled state is still recognizable as a control rather than invisible.

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
- Whiteboard state persists per chat session as JSON under `~/Library/Application Support/CodingBuddy/WhiteboardInvocations/` (`FileMCPAppInvocationStore`); `MCPAppSessionService` rehydrates it on session switch so diagrams survive reopen/relaunch. As in AgentHub, `FileMCPAppInvocationTranscriptReader` reconciles Claude's JSONL `tool_use.id`/`tool_result.tool_use_id` pairs after turns and on restore; local invocation arguments win during the merge because they may contain user edits, while the transcript fills missing results/checkpoint ids. User canvas edits are captured from the app's `save_checkpoint` bridge calls and folded back into the originating invocation's `elements` (plus a local `read_checkpoint` cache) — the WKWebView store is `.nonPersistent()`, so the shell's own localStorage never survives. Live canvases are protected from rewrite redraws by identity-keyed `tool-input` redelivery (`AgentHubMCPUIOutgoingNotification.identity`). MCP app network/CSP grants persist in `MCPAppGrants.json` (`FileMCPAppGrantStore`), keyed by app identity rather than project path; bridge-action approvals remain panel-session scoped and prompt on first use, matching AgentHub
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
