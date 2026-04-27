# Senor Platform Architecture

## Overview

Senor Platform now follows an app-layered architecture inside a single Xcode target. The goal is straightforward ownership:

- `Core` contains cross-cutting primitives such as theme tokens and shared app utilities.
- `Domain` contains business-facing models and request types used by the UI and use cases.
- `Application` composes the app, maps persisted data into domain models, owns routing/shell state, and defines use cases.
- `Infrastructure` is still represented by the existing implementation folders such as `DataLayer`, `TaskEngine`, `SchedulerCore`, `Integrations`, `WorkerRuntime`, and `CacheLayer`.
- `Features` contains screen-scoped SwiftUI flows and feature models.
- `SharedUI` contains reusable UI primitives and visual conventions.

This is still one app target, but dependencies are intentionally one-way.

## Dependency Rules

- `Features -> Application + Domain + SharedUI + Core`
- `Application -> Domain + Core + Infrastructure abstractions`
- `Infrastructure -> Domain + Core`
- `Domain` must not depend on SwiftUI, GRDB, or external client implementations
- `SharedUI` must stay presentation-only and must not reach into repositories or services

## Runtime Composition

The app boots through [`AppBootstrap.swift`](senor-platform/Application/AppBootstrap.swift), which creates repositories, services, background runtime components, and use cases. [`AppShellModel.swift`](senor-platform/Application/AppShellModel.swift) owns initialization and shell-level presentation state. [`AppRouter.swift`](senor-platform/Application/AppRouter.swift) owns navigation and cross-screen selection state.

The old global container still exists as a temporary compatibility shim, but only the bootstrap path and tool service provider are allowed to touch it. New feature code should use explicit dependencies.

## Folder Responsibilities

| Area | Path | Responsibility |
| --- | --- | --- |
| Core | `senor-platform/Core/` | Design tokens and shared app primitives |
| Domain | `senor-platform/Domain/` | App sections, dashboard snapshots, feature-facing models, request/draft types |
| Application | `senor-platform/Application/` | Bootstrap, dependency graph, router, shell model, use cases, record-to-domain mappers |
| Features | `senor-platform/Features/` | App shell, dashboard, agents, tasks, content, approvals, settings |
| Shared UI | `senor-platform/SharedUI/` | Cards, section headers, pills, empty states, shared visual components |
| Data Layer | `senor-platform/DataLayer/` | GRDB records, repositories, database startup and migrations |
| Task Engine | `senor-platform/TaskEngine/` | Approval, publication, content versioning, task execution orchestration |
| Scheduler | `senor-platform/SchedulerCore/` | Schedule DSL, cron compilation, polling scheduler |
| Integrations | `senor-platform/Integrations/` | HTTP, DeviantArt, Patreon, OAuth support |
| Worker Runtime | `senor-platform/WorkerRuntime/` | External worker process lifecycle |
| Agent Tools | `senor-platform/AgentTools/` | Tool contracts and worker-facing tool implementations |

## UI Architecture

The UI is split by feature instead of one root view model:

- `DashboardModel`
- `AgentsModel`
- `TasksModel`
- `ContentModel`
- `ApprovalsModel`
- `SettingsModel`

Each feature model owns only its own screen state and delegates mutations to use cases. Cross-feature refresh is coordinated by `WorkspaceModel`. Navigation and selection live in `AppRouter`, not inside feature models.

## Data Mapping

Persistence records stay in `DataLayer`. Application mappers in [`AppMappers.swift`](senor-platform/Application/AppMappers.swift) convert records into domain-facing models like `Agent`, `TaskSummary`, and `ContentSummary`. SwiftUI features should never consume GRDB record types directly.

## Design System

The shared visual language is defined through:

- [`AppTheme.swift`](senor-platform/Core/AppTheme.swift) for spacing, surfaces, and semantic colors
- [`AppComponents.swift`](senor-platform/SharedUI/AppComponents.swift) for cards, pills, section headers, and empty states

Feature screens should build from these primitives instead of custom one-off styling.

## Architecture Checklist

Use this checklist before merging changes:

- New UI code lives under `Features/` or `SharedUI/`
- New app orchestration or mapping code lives under `Application/`
- New feature views do not resolve services from globals
- Feature models do not own unrelated section state
- Domain types do not import or reference persistence records
- Shared UI components contain styling only, not data access
- Repository records do not cross into SwiftUI features
- Any temporary legacy-container registration stays inside bootstrap or provider adapters

## Current Transitional Notes

- The project still keeps legacy implementation folders alongside the new top-level architecture folders because infrastructure has not been physically renamed yet.
- `sharedContainer` remains as a migration shim for compatibility with worker tooling and older runtime paths.
- `EventBus` is retained for backward compatibility, but the primary app shell no longer depends on it for feature coordination.
