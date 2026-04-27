# Task Engine

**Location:** `senor-platform/TaskEngine/`

## Scope

Task execution pipeline, approval workflow, publication, content versioning.

## Key Files

| File | Responsibility |
|------|----------------|
| `TaskExecutionPipeline.swift` | Orchestrates task execution flow |
| `ApprovalService.swift` | Manages approval queue and workflow |
| `PublicationService.swift` | Handles publishing to platforms |
| `ContentVersioningService.swift` | Content version history |
| `SchemaValidator.swift` | Task input validation |

## Rules

- Pipeline is async/await throughout
- Services are stateless, idempotent
- Approval workflow is event-driven
- Versioning tracks full history

## Dependencies

- Imports: Domain, Core, DataLayer, Integrations
- Must NOT import: SwiftUI, Features
