# Senor Platform

SwiftUI macOS app for managing autonomous agents, scheduling tasks, and publishing content to DeviantArt and Patreon. Includes a local AI chat panel powered by LM Studio.

## What's Built

| Feature | Status |
|---------|--------|
| Agent CRUD | Done |
| Task creation with scheduling | Done |
| Content library with versioning | Done |
| Approval queue (approve/reject/publish) | Done |
| AI chat with context injection | Done |
| DeviantArt OAuth + gallery browse | Done |
| Patreon API integration | Done |
| ComfyUI integration | Done |
| Design system with lint-enforced tokens | Done |
| Offline detection | Done |
| Window sizing settings | Done |

## Architecture

Single Xcode target with one-way dependency layers:

```
Features -> Application + Domain + SharedUI + Core
Application -> Domain + Core + Infrastructure abstractions
Infrastructure -> Domain + Core
```

- **Core**: Design tokens (`AppTheme`), shared primitives
- **Domain**: Business models, no SwiftUI/GRDB/externals
- **Application**: Bootstrap, dependency graph, use cases, mappers, router
- **Features**: Screen-scoped SwiftUI flows with view models
- **SharedUI**: Reusable components (`AppText`, `AppCard`, `AppSurface`)
- **Infrastructure**: GRDB records, HTTP clients, scheduler, worker runtime

### DI & Bootstrapping

`AppBootstrap.swift` creates repositories, services, integrations, and runtime components explicitly. Dependencies flow into feature view models via `AppDependencies`. A legacy container bridge exists for backward compatibility with older worker tooling but new code uses constructor injection exclusively.

### Design System Enforcement

Custom SwiftLint rules prevent raw styling:
- `.font(.body)` -> error, use `AppText`
- `Color.blue` -> error, use `AppTheme.ColorToken`
- `.padding(8)` -> error, use `AppTheme.Spacing`
- `.cornerRadius(4)` -> error, use `AppTheme.CornerRadius`

## Integrations

### DeviantArt
- OAuth2 PKCE flow with state persistence to UserDefaults
- Tokens stored in Keychain
- Gallery browsing, user profile, deviation metadata
- Publish to stash stubbed (endpoint returns 404, non-fatal)

### Patreon
- OAuth + API v2
- Campaign posts, tiers, pledges
- Compose view with oldest-first sorting

### AI Chat (LM Studio)
- OpenAI-compatible Responses API
- Streaming token-by-token
- Context injection: current page state serialized to JSON, truncated to 4000 tokens
- Sliding window: last 15 messages
- Per-section history persisted in SQLite
- Model selection persisted
- Fire-and-forget warmup on bootstrap

### ComfyUI
- External worker process integration
- Execution tracking via GRDB

## Data Layer

- **GRDB** for SQLite persistence
- 10+ repositories (agents, tasks, schedules, runs, content, approvals, publication targets, cache, task types, ComfyUI executions)
- Migrations run on bootstrap
- Domain models never import persistence records

## Task Runtime

- `TaskExecutionPipeline` orchestrates agent runs
- `SchedulerEngine` compiles cron-like schedules and polls for due tasks
- `WorkerProcessManager` manages external worker lifecycle
- `ContentVersioningService` tracks content revisions
- `ApprovalService` / `PublicationService` handle the approve-to-publish flow

## How to Run

Open `senor-platform.xcodeproj` in Xcode. Requires macOS. Build and run.

Configure integrations in Settings:
- **DeviantArt**: Client ID, Client Secret, redirect URI (`senorplatform://oauth/deviantart`)
- **Patreon**: Access token (OAuth via `senorplatform://oauth/patreon`)
- **LM Studio**: Server URL (default `http://localhost:1234/v1`)

## Tech Stack

- Swift 6 (with transitional concurrency annotations)
- SwiftUI
- GRDB
- Combine
- MarkdownUI

## Known Gaps

- DeviantArt stash publish is stubbed (API endpoint unclear)
- Test coverage is thin (~4K test lines, mostly architectural boundary tests)
- Two `@MainActor` blocks disabled in DeviantArt model pending Swift 6 concurrency fixes
- No CI configured
- No root README existed until now

## License

MIT
