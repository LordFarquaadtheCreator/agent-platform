# Agents Feature

Agent CRUD operations and agent list view.

## Key Files

| File | Purpose |
|------|---------|
| `AgentFeature.swift` | Main view: agent list with status, create/edit sheets |
| `AgentFormSheet.swift` | Create/edit agent form |
| `AgentsProviders.swift` | `MainContentProvider` and `InspectorContentProvider` |

## Model Responsibilities

- `AgentsViewModel`: `ObservableObject` managing agent list state
- Sorting by status (active first), display name
- Create via `CreateAgentUseCase`
- Update/delete via repository

## Related

- Agent naming: `AgentNaming/AgentNamingService.swift`
- Agent runtime: `AgentKit/`
