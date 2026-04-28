# DataLayer

GRDB-backed persistence. Records, migrations, repositories. Must not leak into SwiftUI features.

## Key Files

| File | Purpose |
|------|---------|
| `DatabaseManager.swift` | SQLite queue, migrations, Application Support path |
| `Records.swift` | GRDB record structs (AgentRecord, TaskRecord, etc.) |
| `RepositoryProtocols.swift` | Async repository interfaces |
| `RepositoryImplementations.swift` | GRDB query implementations |

## Database Location

`~/Library/Application Support/SenorPlatform/senorplatform.sqlite`

## Migration Policy

Migrations run automatically on `DatabaseManager.startup()`. Add new migration blocks; never modify existing ones.

## Rules

- Records are `Codable` and `PersistableRecord`.
- Repositories are `actor` or `@MainActor` for thread safety.
- Domain models must not import or reference record types (enforced by test).
