# Tasks Feature

Task scheduling, creation, and execution history.

## Key Files

| File | Purpose |
|------|---------|
| `TaskFeature.swift` | Task list with status, agent assignment, schedule info |
| `TaskFormSheet.swift` | Create/edit task with schedule picker |

## Model Responsibilities

- `TasksViewModel`: `ObservableObject` managing task list and creation context
- Load creation context (agents + task types) sorted alphabetically
- Create via `CreateTaskUseCase`
- Supports schedules: one-time, daily, weekly, monthly

## Related

- Scheduler: `SchedulerCore/SchedulerEngine.swift`
- Execution: `TaskEngine/TaskExecutionPipeline.swift`
