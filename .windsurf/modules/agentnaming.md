# Agent Naming

**Location:** `senor-platform/AgentNaming/`

## Scope

Agent name generation utilities.

## Key Files

| File | Responsibility |
|------|----------------|
| `AgentNamer.swift` | Generate unique agent names |

## Rules

- Name generation deterministic or random based on config
- Avoids collisions with existing names
- Theme-based naming optional

## Dependencies

- Imports: Foundation, Core
