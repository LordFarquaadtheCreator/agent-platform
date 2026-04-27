# Content Feature

Generated content library: list, JSON editor, version history.

## Key Files

| File | Purpose |
|------|---------|
| `ContentFeature.swift` | Content list with filter and status |
| `ContentInspectorCard.swift` | Inspector panel for selected content |
| `ContentFeatureProviders.swift` | `MainContentProvider` + `InspectorContentProvider` |

## Sheets

- `ContentJSONEditorSheet`: Edit content JSON payload
- `ContentVersionHistorySheet`: View prior versions

## State

- `ContentViewModel`: `ObservableObject` with filter, selection, status counts
- Supports filtering by status: pending, approved, published, rejected
