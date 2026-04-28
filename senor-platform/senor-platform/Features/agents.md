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
