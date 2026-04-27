# Application Layer

**Location:** `senor-platform/Application/`

## Scope

App bootstrap, dependency graph, routing, use cases, and record-to-domain mapping.

## Key Files

| File | Responsibility |
|------|----------------|
| `AppBootstrap.swift` | Creates repositories, services, background runtime, use cases |
| `AppDependencies.swift` | Dependency container interface |
| `AppRouter.swift` | Navigation and cross-screen selection state |
| `AppShellModel.swift` | Initialization and shell-level presentation state |
| `AppUseCases.swift` | Business operation definitions |
| `AppMappers.swift` | Record-to-domain conversion |
| `LegacyContainerBridge.swift` | Registers bootstrap services into compatibility container |

## Rules

- Bootstrap creates entire dependency graph
- Router owns navigation state, features delegate to it
- Use cases are pure business logic, no SwiftUI
- Mappers convert GRDB records → domain models
- Legacy bridge is ONLY place allowed to touch sharedContainer

## Dependencies

- Imports: Domain, Core, DataLayer, Infrastructure
- Must NOT import SwiftUI (except AppShellModel.swift for @MainActor)
- Must NOT be imported by: Core, Domain, DataLayer
