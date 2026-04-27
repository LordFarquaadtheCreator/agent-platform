# SchedulerCore

Task scheduling engine. Determines when tasks are due and triggers execution.

## Key Files

| File | Purpose |
|------|---------|
| `SchedulerEngine.swift` | Main engine: polls schedules, triggers execution pipeline |
| `ScheduleSpec.swift` | Schedule DSL: daily, weekly, monthly, cron expressions |
| `ScheduleCompiler.swift` | Converts specs to `Date` calculations |

## Schedule Types

- `one_time`: Single execution at specific time
- `daily`: Repeats every day at set time/timezone
- `weekly`: Specific days of week
- `monthly`: Specific day of month

## Polling

- Engine polls every 60 seconds for due tasks.
- Tasks loaded from `TaskScheduleRepository` with `isActive = true` and `nextRunAt <= now`.
- Execution delegated to `TaskExecutionPipeline`.
