# TaskEngine

Task execution, approval queue, publication, and content versioning.

## Key Files

| File | Purpose |
|------|---------|
| `TaskExecutionPipeline.swift` | Orchestrates task runs: validate schema, spawn worker, track state, handle errors |
| `ApprovalService.swift` | Manages content approval queue workflow |
| `PublicationService.swift` | Publishes approved content to configured targets |
| `ContentVersioningService.swift` | Version history for generated content |
| `TaskSchemaValidator.swift` | Validates task metadata JSON against registered schemas |

## Execution Flow

1. `SchedulerEngine` triggers due task
2. `TaskExecutionPipeline.execute(task:schedule:)` validates metadata
3. Worker process spawned via `WorkerProcessManager`
4. Output captured, content record created
5. If approval required, enters `ApprovalQueue`
6. `PublicationService` pushes approved items to DeviantArt/Patreon

## Rules

- Pipeline is an `actor` for serialized execution state.
- Schema validation happens before worker spawn to fail fast.
