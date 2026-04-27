# Content Feature

**Location:** `senor-platform/Features/Content/`

## Scope

Content library UI: browse, filter, version history, metadata editing.

## Key Files

| File | Responsibility |
|------|----------------|
| `ContentFeature.swift` | Main content library view |
| `ContentModel.swift` | Library state |

## Rules

- Grid/list view of content items
- Version history navigation
- Metadata editing forms
- Delegates persistence to use cases

## Dependencies

- Imports: SwiftUI, Domain, Application, Core, SharedUI
