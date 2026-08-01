# CodingBuddy

A macOS interview-prep coding app. Practice technical interviews with an AI interviewer that presents problems, watches you work, gives budgeted hints, and grades you against a real rubric — powered by the local CLI agents you already use (Claude Code or Codex) or any local/OpenAI-compatible model.

## Session modes

- **Mock Interview** — timed, one problem, a strict senior-interviewer persona. Hints only on request, within budget, escalating from a nudge to a skeleton. When the timer expires (or you hit *End & Grade*) the interviewer drops the role-play and grades: correctness, complexity analysis, communication, code quality, speed.
- **Drills** — rapid-fire LeetCode-style reps. Quick verdicts, next question adapts difficulty to your recent scores.
- **Practice** — untimed Socratic tutoring. Explanations and worked solutions allowed after an attempt; gentler optional grading.
- **System Design** — staff-level design interview: requirements → estimation → high-level → deep dives, on a shared **excalidraw whiteboard** rendered in-app via MCP Apps.
- **Behavioral** — STAR coaching, one question at a time with probing follow-ups.

## How it works

- Every question the agent presents is captured into a **local question bank** (SQLite) and can be retried later.
- Evaluations arrive as structured `buddy-eval` blocks in the transcript, parsed and persisted as rubric scores plus **"room for improvement" notes**.
- The **Dashboard** charts per-topic skill, score trends per mode, open improvement notes, and recent attempts with one-click retry.
- Each attempt gets its own workspace under `~/Documents/CodingBuddy/Workspaces/`, editable in the built-in native code editor (tree-sitter highlighting, 43 languages).

## Providers

Interchangeable, selected per session:

- **Claude** — [Claude Code](https://github.com/anthropics/claude-code) CLI via [ClaudeCodeSDK](https://github.com/jamesrochabrun/ClaudeCodeSDK)
- **Codex** — OpenAI Codex CLI via [CodexSDK](https://github.com/jamesrochabrun/CodexSDK)
- **Local / API** — Ollama, LM Studio, any OpenAI-compatible endpoint, or on-device MLX models

Auth is delegated to the underlying CLI — no API keys stored by the app.

## Building

```bash
xcodebuild -project CodingBuddy.xcodeproj -scheme CodingBuddy build
```

Packages (`swift test` in each, or run the `CodingBuddyChat` scheme tests via Xcode):

| Package | Role |
|---|---|
| `InterviewKit` | Domain models, SQLite question bank / attempts / evaluations, timer, parsers |
| `CodingBuddyChat` | Chat service, interview prompts, sidebar, surfaces, dashboard |
| `CodingBuddyClaudeCodeUI` | Chat engine (module `ClaudeCodeCore`): view models, streaming, storage, permissions |
| `BuddyMCPUI` | MCP Apps host: WKWebView JSON-RPC bridge, MCP clients, side panel |
| `CodingBuddyKit` | Zero-dep protocol seams and design tokens |
| `CodingBuddyAgentHarness` / `CodingBuddyAgentMLX` | Local/API agent loop + on-device MLX |

## Data locations

- Question bank / attempts / evaluations: `~/Library/Application Support/CodingBuddy/interview_bank.sqlite`
- Chat sessions: `~/Library/Application Support/CodingBuddy/claude_code_sessions.sqlite`
- Attempt workspaces: `~/Documents/CodingBuddy/Workspaces/`
- MCP servers (whiteboard etc.): `~/.config/claude/mcp-config.json`

## License

See [LICENSE](LICENSE).
