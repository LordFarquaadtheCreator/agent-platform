# Application

Dependency graph, bootstrapping, routing, shell state, use cases, and mappers. Owned by app layer, consumed by Features.

## Key Files

| File | Purpose |
|------|---------|
| `AppBootstrap.swift` | Creates repositories, services, integrations, runtime; wires legacy bridge |
| `AppDependencies.swift` | Dependency bag passed to feature models |
| `AppShellModel.swift` | Root `@StateObject`: initialization state, sheet presentation, toast, refresh coordination |
| `AppRouter.swift` | Navigation and cross-screen selection state |
| `AppUseCases.swift` | Use case implementations (agent/task/content creation) |
| `AppMappers.swift` | GRDB record-to-domain model conversion |
| `LegacyContainerBridge.swift` | Single place allowed to register bootstrap services into `sharedContainer` |
| `AgentKitServiceProvider.swift` | Tool service provider adapter for worker runtime |

## Bootstrap Order

1. `DatabaseManager` startup (migrations)
2. Repository creation (all GRDB-backed)
3. Service creation (settings, cache)
4. Integration setup (DeviantArt, Patreon clients)
5. Task runtime (scheduler, execution pipeline)
6. Legacy bridge registration (temporary)

## Rules

- `AppShellModel` owns sheet enum and error presentation.
- Feature models own only their screen state; navigation lives in `AppRouter`.
- New code must use explicit dependencies, never `sharedContainer`.
