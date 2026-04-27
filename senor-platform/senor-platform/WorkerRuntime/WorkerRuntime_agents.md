# WorkerRuntime

External worker process lifecycle. Spawns command-line tools for task execution.

## Key Files

| File | Purpose |
|------|---------|
| `WorkerProcessManager.swift` | Spawns, monitors, and terminates worker subprocesses |

## Process Model

- Workers are spawned as `Process` (NSTask) instances.
- stdin/stdout piped for JSON protocol communication.
- Exit code and timeout handling managed here.

## Rules

- Task script path resolved via `SettingsService.taskScriptPath()`.
- Worker crashes surfaced as `AppError.workerFailed`.
