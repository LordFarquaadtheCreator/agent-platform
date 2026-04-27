# Settings Feature

**Location:** `senor-platform/Features/Settings/`

## Scope

App settings UI: preferences, integrations, account management.

## Key Files

| File | Responsibility |
|------|----------------|
| `SettingsFeature.swift` | Settings view |
| `SettingsModel.swift` | Settings state |

## Rules

- User preferences (stored via settings repository)
- OAuth connection management (DeviantArt, Patreon)
- Theme/accent color selection
- Export/import data

## Dependencies

- Imports: SwiftUI, Domain, Application, Core, SharedUI
