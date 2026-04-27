# Tasks Feature

**Location:** `senor-platform/Features/Tasks/`

## Scope

Task orchestration UI: list, queue, execute, monitor task status.

## Key Files

| File | Responsibility |
|------|----------------|
| `TaskFeature.swift` | Main feature view |
| `TasksModel.swift` | Feature state |

## Rules

- Model owns task list state
- Delegates execution to TaskEngine use cases
- Real-time status updates via observation
- Uses SharedUI for status pills

## Dependencies

- Imports: SwiftUI, Domain, Application, Core, SharedUI
