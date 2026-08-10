# Spar

Spar is a native macOS app for deliberate technical-interview practice. It pairs an AI
interviewer with a real coding workspace, source-grounded repository study, structured
feedback, and progress tracking so you can practice the way you expect to perform.

Use Spar for a timed mock interview, a quick sequence of drills, an untimed tutoring
session, a system-design discussion, or behavioral coaching. You choose the AI provider
for each session and keep your attempts, study plans, and progress on your Mac.

## What you can do

### Practice in five modes

- **Mock Interview** — Complete one timed problem with limited, progressively stronger
  hints, then receive rubric-based feedback.
- **Drills** — Work through rapid-fire problems whose difficulty adapts to your recent
  answers.
- **Practice** — Learn through untimed, interactive tutoring with explanations and
  worked solutions when you need them.
- **System Design** — Clarify requirements, estimate scale, sketch a design on the
  integrated whiteboard, and defend your trade-offs.
- **Behavioral** — Develop STAR stories through realistic questions and probing
  follow-ups.

### Learn a repository

Add a local repository as a study resource and Spar will:

1. Index supported source and documentation files into searchable passages.
2. Inspect the repository's structure and concepts.
3. Generate a source-grounded learning plan organized as a flexible checklist.
4. Start an interactive study session from any plan item.
5. Preserve completion state so you can stop, revisit topics, or learn out of order.

Adding a repository is read-only: Spar does not run `git add`, create commits, push
changes, or modify the source repository. The searchable index is stored locally. When
you ask a source-grounded question, relevant passages may be sent to the AI provider you
selected for that session.

### Work and review in one place

- A per-attempt coding workspace with an integrated source editor
- Source browsing and citations for repository-backed study
- A whiteboard for system-design sessions
- Configurable hint budgets
- Structured grading with scores, verdicts, and improvement notes
- A dashboard for topic-level skill, score trends, and past attempts
- Persistent reports and one-click retry

## AI providers

Spar supports interchangeable providers selected per session:

- **Claude** through the [Claude Code](https://github.com/anthropics/claude-code) CLI
- **Codex** through the OpenAI Codex CLI
- **Local / API** through Ollama, LM Studio, OpenAI-compatible endpoints, or on-device
  MLX models

Claude and Codex authentication is delegated to their CLIs. Spar does not store their API
keys.

## Building

Requirements:

- macOS with a current version of Xcode
- Authentication or local configuration for at least one supported AI provider

Clone the repository and build the app:

```bash
git clone https://github.com/jamesrochabrun/Spar.git
cd Spar
xcodebuild -project CodingBuddy.xcodeproj -scheme CodingBuddy build
```

Open `CodingBuddy.xcodeproj` in Xcode if you prefer to build and run from the IDE.

## Architecture

| Package | Responsibility |
| --- | --- |
| `InterviewKit` | Session models, question bank, attempts, evaluations, timers, and structured-output parsers |
| `KnowledgeKit` | Repository indexing, search, study spaces, learning plans, and local persistence |
| `CodingBuddyChat` | Chat orchestration, prompts, sidebar, editor surfaces, reports, dashboard, and study UI |
| `CodingBuddyClaudeCodeUI` | Provider runtime, streaming chat, session storage, and permissions |
| `BuddyMCPUI` | MCP Apps hosting and the in-app side panel |
| `CodingBuddyKit` | Shared protocols, branding, and design tokens |
| `CodingBuddyAgentHarness` / `CodingBuddyAgentMLX` | Local/API agent loop and on-device MLX support |

The app parses two structured transcript contracts:

- `buddy-question/v1` captures generated interview questions in the local question bank.
- `buddy-eval/v1` captures rubric scores, verdicts, summaries, and improvement notes.

## Local data

Spar keeps its durable data on your Mac:

| Data | Location |
| --- | --- |
| Attempt workspaces | `~/Documents/CodingBuddy/Workspaces/` |
| Questions, attempts, and evaluations | `~/Library/Application Support/CodingBuddy/interview_bank.sqlite` |
| Chat sessions | `~/Library/Application Support/CodingBuddy/claude_code_sessions.sqlite` |
| Repository indexes and study plans | `~/Library/Application Support/CodingBuddy/knowledge_library.sqlite` |
| MCP configuration | `~/.config/claude/mcp-config.json` |

The `CodingBuddy` directory names are retained as stable internal storage identifiers so
existing local data continues to work after the app's rename to Spar.

## Testing

Package tests live beside each package in `Packages/*/Tests`. `swift test` works for
`InterviewKit`, `KnowledgeKit`, `CodingBuddyKit`, and `BuddyMCPUI`. Run
`CodingBuddyChat` tests through Xcode because of its transitive dependencies:

```bash
xcodebuild test -scheme CodingBuddyChat -destination 'platform=macOS'
```

Run app-level tests with:

```bash
xcodebuild test \
  -project CodingBuddy.xcodeproj \
  -scheme CodingBuddy \
  -destination 'platform=macOS'
```

## License

See [LICENSE](LICENSE).
