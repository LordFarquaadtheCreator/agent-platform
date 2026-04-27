# Worker Runtime

**Location:** `senor-platform/WorkerRuntime/`

## Scope

External worker process lifecycle management.

## Key Files

| File | Responsibility |
|------|----------------|
| `WorkerProcessManager.swift` | Spawn, monitor, terminate worker processes |

## Rules

- Workers are sandboxed subprocesses
- Manager handles stdout/stderr streaming
- Process lifecycle: spawn → monitor → cleanup
- Health checks and restart logic

## Dependencies

- Imports: Foundation, Core
- Must NOT import: SwiftUI
