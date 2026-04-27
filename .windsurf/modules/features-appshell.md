# App Shell Feature

**Location:** `senor-platform/Features/AppShell/`

## Scope

Root shell UI: split view, sidebar, toolbar, inspector composition.

## Key Files

| File | Responsibility |
|------|----------------|
| `AppShellView.swift` | Root shell layout |
| `SidebarView.swift` | Navigation sidebar |
| `InspectorView.swift` | Right-side inspector |

## Rules

- Owns overall window layout
- Manages sidebar selection state (via AppRouter)
- Handles toolbar actions
- Coordinates feature transitions

## Dependencies

- Imports: SwiftUI, Domain, Application, Core, SharedUI, all Features
