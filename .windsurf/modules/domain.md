# Domain Layer

**Location:** `senor-platform/Domain/`

## Scope

Pure business models, request types, and feature-facing types. No persistence, no UI.

## Key Files

| File | Responsibility |
|------|----------------|
| `AppModels.swift` | Agent, Task, Content, Approval domain types |
| `AppSections.swift` | App section enums, dashboard snapshots |

## Rules

- NO SwiftUI imports
- NO GRDB imports
- NO external client imports
- Pure structs/enums with business logic
- Used by both Application and Features layers

## Dependencies

- Imports: Foundation only
- Must NOT import: SwiftUI, GRDB, any client libraries
- Can be imported by: ALL layers above
