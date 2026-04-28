# Domain

Pure domain models, enums, and request/draft types. No SwiftUI, GRDB, or external client dependencies.

## Key Files

| File | Purpose |
|------|---------|
| `AppModels.swift` | `Agent`, `TaskSummary`, `ContentSummary`, `AppSection`, `PublicationPlatform`, `ContentWorkflowStatus` |

## Model Rules

- Must not reference `Record` types (enforced by `testDomainModelsDoNotReferencePersistenceRecords`).
- Must not import `SwiftUI`, `GRDB`, or integration clients.
- Used by both UI and use cases.

## Key Enums

- `AppSection`: dashboard, agents, tasks, content, approvals, tools, deviantArt, patreon, settings
- `PublicationPlatform`: deviantart, patreon
- `ContentWorkflowStatus`: pending, approved, published, rejected
