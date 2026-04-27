# Senor Platform - Root Agent Configuration

## Project Overview

macOS agent management platform for content creation, task orchestration, and multi-platform publishing. Swift/SwiftUI with GRDB persistence.

## Architecture Stack

```
Features (SwiftUI screens)
    ↓
Application (Use cases, routing, bootstrap)
    ↓
Domain (Business models)
    ↓
DataLayer (GRDB records, repositories)
    ↓
Infrastructure (TaskEngine, Scheduler, Integrations, WorkerRuntime)
```

## Critical Rules

### Dependency Direction (ENFORCED)
- `Features → Application + Domain + SharedUI + Core`
- `Application → Domain + Infrastructure abstractions`
- `Infrastructure → Domain + Core`
- `Domain` must NOT import SwiftUI, GRDB, or external clients
- `SharedUI` presentation-only, no data access

### Forbidden Patterns
- ❌ Domain types referencing persistence records
- ❌ Feature views resolving services from globals
- ❌ SwiftUI features consuming GRDB types directly
- ❌ Repository records crossing into SwiftUI
- ❌ SharedUI components accessing repositories

### Required Patterns
- ✅ MVVM: FeatureModel owns screen state, delegates to UseCases
- ✅ Navigation in `AppRouter`, not in feature models
- ✅ Explicit dependency injection via bootstrap
- ✅ Records → Domain models via `AppMappers.swift`

## File Organization

| Layer | Path | Contains |
|-------|------|----------|
| Core | `Core/` | AppTheme, primitives |
| Domain | `Domain/` | Business models |
| Application | `Application/` | Bootstrap, routing, use cases, mappers |
| Features | `Features/*/` | Screen-scoped SwiftUI |
| SharedUI | `SharedUI/` | Reusable components |
| Data | `DataLayer/` | GRDB, repositories |
| Infra | `TaskEngine/`, `SchedulerCore/`, `Integrations/`, `WorkerRuntime/`, `CacheLayer/`, `AgentTools/` | Services |
| Legacy | `AppCore/`, `Views/` | Compatibility shims |

## Entry Points

- `senor_platformApp.swift` - App launch, shell model install
- `ContentView.swift` - Root view with bootstrap states
- `AppBootstrap.swift` - Dependency graph construction

## Module Agents

Each module documented in `.windsurf/modules/`:

| Module | File | Location |
|--------|------|----------|
| Application | `application.md` | Bootstrap, routing, use cases |
| DataLayer | `datalayer.md` | GRDB persistence |
| Domain | `domain.md` | Business models |
| Core | `core.md` | Theme tokens |
| SharedUI | `sharedui.md` | Reusable components |
| Agents Feature | `features-agents.md` | Agent management UI |
| Tasks Feature | `features-tasks.md` | Task orchestration UI |
| Content Feature | `features-content.md` | Content library UI |
| Approvals Feature | `features-approvals.md` | Approval workflow UI |
| Dashboard Feature | `features-dashboard.md` | Dashboard UI |
| Settings Feature | `features-settings.md` | Settings UI |
| App Shell | `features-appshell.md` | Shell layout |
| AgentKit | `agentkit.md` | Agent framework |
| TaskEngine | `taskengine.md` | Task execution |
| Scheduler | `scheduler.md` | Scheduling |
| Integrations | `integrations.md` | External APIs |
| Worker | `worker.md` | Process management |
| Cache | `cache.md` | Caching |
| AgentTools | `agenttools.md` | Tool contracts |
| AppCore | `appcore.md` | Legacy compatibility |
| Views | `views.md` | Legacy views |
| AgentNaming | `agentnaming.md` | Naming utilities |

## Quick Reference

- Architecture: `ARCHITECTURE.md`
- Directory map: `DIRECTORY.md`
- Design system: `Core/AppTheme.swift` + `SharedUI/AppComponents.swift`
