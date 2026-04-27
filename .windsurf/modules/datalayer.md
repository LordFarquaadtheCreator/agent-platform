# Data Layer

**Location:** `senor-platform/DataLayer/`

## Scope

GRDB persistence, database records, repositories, migrations.

## Key Files

| File | Responsibility |
|------|----------------|
| `DatabaseManager.swift` | GRDB setup, migrations, pool management |
| `Records.swift` | GRDB record definitions (tables) |
| `RepositoryProtocols.swift` | Repository interfaces |
| `RepositoryImplementations.swift` | Concrete repositories |

## Rules

- Records are GRDB-bound structs (Codable, FetchableRecord, etc.)
- Repositories return records, NOT domain models
- Repository protocols live here, implementations too
- Database access is async/await
- Migrations versioned in DatabaseManager

## Dependencies

- Imports: GRDB, Core
- Must NOT import: SwiftUI, Application, Domain (circular)
- Exports records upward to Application for mapping
