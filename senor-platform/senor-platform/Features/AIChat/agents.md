# AI Chat Feature

AI chat panel for discussing current page context with local LLM.

## Context Injection

ContextExtractor extracts full page state:
- Dashboard: snapshot stats, recent content
- Agents: selected agent, agent list
- Tasks: selected task, task list, creation context
- Content: selected content, content list
- Approvals: pending approvals
- DeviantArt: auth state, profile, deviations
- Patreon: auth state, posts, members, tiers
- Tools: available tools
- Settings: current settings

All serialized to JSON, truncated to 4000 tokens.

## Sliding Window

Keeps last 15 messages. Drops oldest when exceeding budget.

## Persistence

ChatHistoryStore persists per-section history in SQLite.
- Table: chat_history
- Upsert on save
- Load on view appear
- Clear on user action

## Usage

```swift
let viewModel = AIChatViewModel(
    aiClient: AIClient(),
    contextExtractor: ContextExtractor(),
    chatHistoryStore: ChatHistoryStore(databaseManager: db),
    workspace: workspace,
    router: router
)

AIChatView(viewModel: viewModel)
```

## Dependencies

- AIService (AIClient, AIModels)
- ContextExtractor
- ChatHistoryStore
- WorkspaceModel
- AppRouter
