# Scheduler Core

**Location:** `senor-platform/SchedulerCore/`

## Scope

Task scheduling: cron expressions, schedule DSL, polling scheduler engine.

## Key Files

| File | Responsibility |
|------|----------------|
| `SchedulerEngine.swift` | Polling engine, task triggering |
| `ScheduleSpec.swift` | Schedule DSL and cron compilation |

## Rules

- Cron expressions compiled to next-run timestamps
- Engine polls and triggers due tasks
- Schedule specs are serializable
- Handles timezone correctly

## Dependencies

- Imports: Foundation, Core, Domain
- Must NOT import: SwiftUI, GRDB directly (use repositories)
