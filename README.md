# Senor Platform

A SwiftUI macOS application for managing autonomous agents, scheduling tasks, and publishing content to DeviantArt and Patreon. Features local AI integration via LM Studio and ComfyUI workflow execution.

## Features

- **Agent Management**: Create, configure, and monitor autonomous agents
- **Task Scheduling**: Define and schedule agent tasks with cron-like expressions
- **Content Workflow**: Generate, version, approve, and publish content
- **Approval Queue**: Content approval/rejection workflow before publication
- **Multi-Platform Publishing**: Unified interface for DeviantArt and Patreon
- **AI Chat**: Local LLM integration via LM Studio with context injection
- **ComfyUI Integration**: Stable Diffusion workflow execution
- **Design System**: SwiftLint-enforced design tokens for visual consistency
- **Offline Resilience**: Connectivity detection prevents API calls when offline

## Architecture

Single Xcode target with intentional one-way dependency layers:

```
Features → Application + Domain + SharedUI + Core
Application → Domain + Core + Infrastructure abstractions
Infrastructure → Domain + Core
Domain → (no external dependencies)
```

### Layer Responsibilities

| Layer | Responsibility |
|-------|-----------------|
| **Core** | Design tokens, logging, error handling, settings |
| **Domain** | Pure business models (Agent, Task, Content) — no SwiftUI/GRDB |
| **Application** | Bootstrap, DI graph, routing, use cases, record-to-domain mappers |
| **Features** | Screen-scoped SwiftUI flows (Dashboard, Agents, Tasks, Content, etc.) |
| **SharedUI** | Reusable components (AppText, AppCard, AppMetricCard) |
| **DataLayer** | GRDB records, migrations, repositories |
| **TaskEngine** | Task execution pipeline, approval/publication services |
| **SchedulerCore** | Schedule DSL, polling scheduler, cron compilation |
| **Integrations** | HTTP client, DeviantArt, Patreon OAuth clients |
| **Infrastructure** | AI service (LM Studio client) |
| **WorkerRuntime** | External worker process lifecycle |
| **AgentKit** | Tool registry, runner, built-in tools |
| **CacheLayer** | TTL-based caching for API responses |

## Prerequisites

- macOS 26.3 or later
- Xcode 15 or later
- Swift 6
- LM Studio (optional, for AI chat features)
- ComfyUI (optional, for Stable Diffusion workflows)

## Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/senor-app.git
cd senor-app
```

2. Open the project in Xcode:
```bash
open senor-platform.xcodeproj
```

3. Build and run the project from Xcode (⌘R)

## Configuration

### DeviantArt Integration

1. Create a DeviantArt application at [https://www.deviantart.com/developers](https://www.deviantart.com/developers)
2. Obtain Client ID and Client Secret
3. In the app Settings, configure:
   - Client ID
   - Client Secret
   - Redirect URI: `senorplatform://oauth/deviantart`

### Patreon Integration

1. Create a Patreon application at [https://www.patreon.com/portal/registration/register-clients](https://www.patreon.com/portal/registration/register-clients)
2. Obtain access token via OAuth
3. In the app Settings, configure:
   - Access Token
   - Redirect URI: `senorplatform://oauth/patreon`

### LM Studio (AI Chat)

1. Install [LM Studio](https://lmstudio.ai/)
2. Load a model and start the server
3. Default server URL: `http://localhost:1234/v1`
4. Configure in app Settings if using a different port

### ComfyUI

1. Install [ComfyUI](https://github.com/comfyanonymous/ComfyUI)
2. Start the ComfyUI server
3. Default server URL: `http://127.0.0.1:8000`
4. Place workflows in `~/Documents/ComfyUI/user/default/workflows`

## Usage

### Creating Agents

1. Navigate to the Agents section
2. Click "Create Agent"
3. Configure agent name, status, and task associations

### Scheduling Tasks

1. Navigate to the Tasks section
2. Click "Create Task"
3. Define task name, schedule (cron-like expression), and associated agent
4. Tasks are polled every 30 seconds for execution

### Content Workflow

1. Tasks generate content which appears in the Content library
2. Review content in the Approvals queue
3. Approve or reject content
4. Approved content can be published to configured platforms

### AI Chat

1. Navigate to the AI Chat section
2. Select a model from LM Studio
3. Current page state is automatically injected as context
4. Chat history is persisted per section

## Development

### Tech Stack

- Swift 6 (with transitional concurrency annotations)
- SwiftUI (macOS-only)
- GRDB (SQLite persistence)
- MarkdownUI (Markdown rendering)
- NetworkImage (Async image loading)
- Combine (Reactive state)

### Design System

Custom SwiftLint rules enforce design tokens:
- Use `AppText` instead of `.font(.body)`
- Use `AppTheme.ColorToken` instead of `Color.blue`
- Use `AppTheme.Spacing` instead of `.padding(8)`
- Use `AppTheme.CornerRadius` instead of `.cornerRadius(4)`

### Database

- Location: `~/Library/Application Support/SenorPlatform/senorplatform.sqlite`
- Migrations run automatically on app startup
- Schema includes 10+ tables for agents, tasks, content, approvals, etc.

## Testing

Run tests from Xcode (⌘U) or via command line:

```bash
xcodebuild test -scheme senor-platform -destination 'platform=macOS'
```

Test coverage is focused on architectural boundaries and use case integration.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on contributing to Senor Platform.

## License

MIT License - see LICENSE file for details
