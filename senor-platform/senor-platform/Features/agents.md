# Features

Screen-scoped SwiftUI flows and feature models. Each feature owns its own screen state.

## Structure

| Feature | Model | Screen | Notes |
|---------|-------|--------|-------|
| AppShell | `AppShellView` | Shell layout | Split view, toolbar, inspector composition |
| Dashboard | `DashboardFeature` | Dashboard screen | Metrics, quick actions |
| Agents | `AgentFeature` | Agent list/form | Create, edit, delete agents |
| Tasks | `TaskFeature` | Task list/form | Scheduling, execution history |
| Content | `ContentFeature` | Content library | JSON editor, version history |
| Approvals | `ApprovalsFeature` | Approval queue | Approve/reject workflow |
| DeviantArt | `DeviantArtModel` | Gallery browser | OAuth, gallery, stash, publish |
| Patreon | `PatreonModel` | Post composer | Campaign posts, tiers |
| Settings | `SettingsFeature` | Configuration | Integration credentials, general |

## Rules

- Feature models are `ObservableObject`.
- Views consume `AppDependencies` from environment or constructor.
- No global service resolution (enforced by test).
- All styling via `SharedUI` components and `AppTheme` tokens.

## SwiftUI Preview System

All feature previews use dependency injection with mock repositories and services.

### Mock Infrastructure

Located in `PreviewMocks.swift`:
- Mock repositories (Agent, Task, Content, Approval)
- Mock API clients (DeviantArtClient, PatreonClient)
- Mock services (SettingsService)
- Preview data builders

Located in `PreviewHelpers.swift`:
- Factory functions for ViewModels: `previewAgentsViewModel()`, `previewTasksViewModel()`, etc.
- Pre-configured with realistic mock data

### Pattern

```swift
#Preview("State Name") {
    let viewModel = previewFeatureViewModel(configuration: .populated)
    return FeatureScreen(viewModel: viewModel)
}
```

### Benefits

1. Real ViewModels execute real code paths
2. Mock dependencies control data/state
3. No static factory maintenance
4. Tests and previews share mocks

### Available Helpers

| Function | Purpose |
|----------|---------|
| `previewAgentsViewModel()` | Agents list with mock agents |
| `previewTasksViewModel()` | Tasks with schedules |
| `previewContentViewModel()` | Content library |
| `previewApprovalsViewModel()` | Approval queue |
| `previewDashboardViewModel()` | Dashboard metrics |
| `previewDeviantArtViewModel()` | DeviantArt gallery |
| `previewPatreonViewModel()` | Patreon posts/members |
| `previewSettingsViewModel()` | Settings form |
| `previewWorkspaceModel()` | Full workspace |
