# Agent Tools

**Location:** `senor-platform/AgentTools/`

## Scope

Tool contracts and worker-facing tool implementations.

## Key Files

| File | Responsibility |
|------|----------------|
| `ToolProtocols.swift` | Tool interface definitions |
| `AgentRunner.swift` | Worker-side agent execution |
| `PublishingTools.swift` | Publishing tool implementations |

## Rules

- Tools are pure functions: input → output
- Contracts define schemas and validation
- Runner executes agents in worker context
- Publishing tools handle platform-specific logic

## Dependencies

- Imports: Core, Domain, AgentKit
- Must NOT import: SwiftUI, Features
