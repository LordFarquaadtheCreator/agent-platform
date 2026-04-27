# AgentNaming

Generates deterministic agent display names from seed and source.

## Key Files

| File | Purpose |
|------|---------|
| `AgentNamingService.swift` | Name generation logic |

## Naming Sources

- `manual`: User-provided name
- `seeded`: Generated from `nameSeed` integer using word lists
- `random`: Random adjective-noun combinations

## Rules

- Names must be unique within the workspace.
- Service checks `AgentRepository.existsWithName()` before returning.
