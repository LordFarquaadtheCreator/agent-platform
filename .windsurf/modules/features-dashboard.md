# Dashboard Feature

**Location:** `senor-platform/Features/Dashboard/`

## Scope

Main dashboard UI: overview cards, recent activity, quick actions.

## Key Files

| File | Responsibility |
|------|----------------|
| `DashboardFeature.swift` | Dashboard view |
| `DashboardModel.swift` | Dashboard state |

## Rules

- Read-only overview of system state
- Quick navigation to other features
- Recent tasks, pending approvals summary
- Uses SharedUI card components

## Dependencies

- Imports: SwiftUI, Domain, Application, Core, SharedUI
