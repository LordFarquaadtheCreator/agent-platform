# Agents Feature

**Location:** `senor-platform/Features/Agents/`

## Scope

Agent management UI: list, create, edit, configure capabilities.

## Key Files

| File | Responsibility |
|------|----------------|
| `AgentFeature.swift` | Main feature view |
| `AgentsModel.swift` | Feature state and actions |

## Rules

- Model owns screen state only
- Delegates mutations to UseCases
- Navigation via AppRouter (passed in or environment)
- Uses SharedUI components
- No direct repository access

## Dependencies

- Imports: SwiftUI, Domain, Application, Core, SharedUI
- Uses: UseCases via dependency injection
