# Agent Kit

**Location:** `senor-platform/AgentKit/`

## Scope

Agent framework: agent definitions, protocols, tools, logging system.

## Submodules

| Folder | Contains |
|--------|----------|
| `Agent/` | Agent definitions, capabilities, configuration |
| `Tools/` | Tool protocols and implementations |
| `Logging/` | Agent logging system |

## Key Files

- `Agent/Capability.swift` - Agent capability definitions
- `Agent/Configuration.swift` - Agent config models
- `Tools/ToolProtocols.swift` - Tool interface contracts
- `Logging/AgentLogger.swift` - Structured logging for agents

## Rules

- Tool protocols define clear input/output contracts
- Capabilities are composable
- Logging is structured and searchable
- No UI code in agent execution

## Dependencies

- Imports: Core, Domain
- Must NOT import: SwiftUI, Features, Application (use cases call here)
