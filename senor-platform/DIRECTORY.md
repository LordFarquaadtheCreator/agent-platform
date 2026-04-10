# Senor Platform Directory

Quick navigation to all major components of the application.

---

## 📋 Architecture Documentation

| Document | Description |
|----------|-------------|
| **[ARCHITECTURE.md](ARCHITECTURE.md)** | Complete system architecture, data flows, and design patterns |
| **[DIRECTORY.md](DIRECTORY.md)** | This file - quick navigation to all source files |

---

## 🎯 Entry Points

| Component | File | Purpose |
|-----------|------|---------|
| **App Entry** | [`senor_platformApp.swift`](senor-platform/senor_platformApp.swift:13) | `@main` struct, AppState, initialization sequence |
| **Root View** | [`ContentView.swift`](senor-platform/ContentView.swift:11) | Main window with NavigationSplitView |

---

## 🧱 Core Infrastructure (AppCore)

**Directory:** [`senor-platform/AppCore/`](senor-platform/AppCore/)

| File | Responsibility | Key Types |
|------|---------------|-----------|
| [`DependencyContainer.swift`](senor-platform/AppCore/DependencyContainer.swift:16) | Service locator, DI container | `DependencyContainer`, `LifecycleAware` |
| [`EventBus.swift`](senor-platform/AppCore/EventBus.swift:6) | Type-safe event system | `EventBus`, `RefreshEvent`, `ActionEvent` |
| [`ServiceProtocols.swift`](senor-platform/AppCore/ServiceProtocols.swift:1) | Service interfaces | `AgentNamingServiceProtocol`, `CacheServiceProtocol`, `ApprovalServiceProtocol` |
| [`SettingsService.swift`](senor-platform/AppCore/SettingsService.swift:1) | Secure settings persistence | `SettingsService` |
| [`AppLogger.swift`](senor-platform/AppCore/AppLogger.swift:1) | Structured logging | `AppLogger` |
| [`AppError.swift`](senor-platform/AppCore/AppError.swift:1) | Error taxonomy | `AppError` |
| [`Keychain.swift`](senor-platform/AppCore/Keychain.swift:1) | Secure storage | `Keychain` |
| [`StatusEnums.swift`](senor-platform/AppCore/StatusEnums.swift:1) | Shared enums | `AgentStatus`, `TaskStatus`, etc. |
| [`StatusColor.swift`](senor-platform/AppCore/StatusColor.swift:1) | UI colors | `StatusColor` |
| [`JSONUtils.swift`](senor-platform/AppCore/JSONUtils.swift:1) | JSON helpers | JSON utilities |

---

## 💾 Data Layer (DataLayer)

**Directory:** [`senor-platform/DataLayer/`](senor-platform/DataLayer/)

| File | Responsibility | Key Types |
|------|---------------|-----------|
| [`DatabaseManager.swift`](senor-platform/DataLayer/DatabaseManager.swift:6) | Database connection, migrations | `DatabaseManager` |
| [`Records.swift`](senor-platform/DataLayer/Records.swift:8) | Database entities | `AgentRecord`, `TaskRecord`, `TaskRunRecord`, `GeneratedContentRecord`, etc. |
| [`RepositoryProtocols.swift`](senor-platform/DataLayer/RepositoryProtocols.swift:4) | Repository interfaces | `AgentRepository`, `TaskRepository`, `TaskScheduleRepository`, etc. |
| [`RepositoryImplementations.swift`](senor-platform/DataLayer/RepositoryImplementations.swift:1) | Data access implementation | `AgentRepositoryImpl`, `TaskRepositoryImpl`, etc. |

### Database Entities

| Entity | Record | Repository | Description |
|--------|--------|------------|-------------|
| **Agent** | [`AgentRecord`](senor-platform/DataLayer/Records.swift:8) | [`AgentRepository`](senor-platform/DataLayer/RepositoryProtocols.swift:4) | AI agent definitions |
| **Task** | [`TaskRecord`](senor-platform/DataLayer/Records.swift:87) | [`TaskRepository`](senor-platform/DataLayer/RepositoryProtocols.swift:16) | Task configurations |
| **TaskType** | [`TaskTypeRecord`](senor-platform/DataLayer/Records.swift:55) | [`TaskTypeRepository`](senor-platform/DataLayer/RepositoryProtocols.swift:96) | Task schema definitions |
| **TaskSchedule** | [`TaskScheduleRecord`](senor-platform/DataLayer/Records.swift:128) | [`TaskScheduleRepository`](senor-platform/DataLayer/RepositoryProtocols.swift:27) | Cron/recurring schedules |
| **TaskRun** | [`TaskRunRecord`](senor-platform/DataLayer/Records.swift:172) | [`TaskRunRepository`](senor-platform/DataLayer/RepositoryProtocols.swift:38) | Execution history |
| **GeneratedContent** | [`GeneratedContentRecord`](senor-platform/DataLayer/Records.swift:206) | [`GeneratedContentRepository`](senor-platform/DataLayer/RepositoryProtocols.swift:50) | AI-generated content |
| **ContentVersion** | [`GeneratedContentVersionRecord`](senor-platform/DataLayer/Records.swift:226) | Same as above | Content revisions |
| **ApprovalQueue** | [`ApprovalQueueRecord`](senor-platform/DataLayer/Records.swift:246) | [`ApprovalQueueRepository`](senor-platform/DataLayer/RepositoryProtocols.swift:65) | Approval workflow |
| **PublicationTarget** | [`PublicationTargetRecord`](senor-platform/DataLayer/Records.swift:273) | [`PublicationTargetRepository`](senor-platform/DataLayer/RepositoryProtocols.swift:76) | Platform publication state |
| **RemotePostCache** | [`RemotePostCacheRecord`](senor-platform/DataLayer/Records.swift:294) | [`RemotePostCacheRepository`](senor-platform/DataLayer/RepositoryProtocols.swift:86) | API response cache |

---

## 🤖 Agent Tools (AgentTools)

**Directory:** [`senor-platform/AgentTools/`](senor-platform/AgentTools/)

| File | Responsibility | Key Types |
|------|---------------|-----------|
| [`ToolProtocols.swift`](senor-platform/AgentTools/ToolProtocols.swift:1) | Tool framework | `AgentTool`, `ToolExecutionContext`, `ToolRegistry`, `ToolError` |
| [`AgentRunner.swift`](senor-platform/AgentTools/AgentRunner.swift:5) | Agent execution entry | `AgentRunner`, `AgentStatus`, `AgentResult` |
| [`ComfyUITool.swift`](senor-platform/AgentTools/ComfyUITool.swift:4) | Image generation | `ComfyUITool` |
| [`ImageComposerTool.swift`](senor-platform/AgentTools/ImageComposerTool.swift:1) | Image composition | `ImageComposerTool` |
| [`PublishingTools.swift`](senor-platform/AgentTools/PublishingTools.swift:1) | Platform publishing | `DeviantArtPublishTool`, `PatreonPublishTool` |

---

## 🔌 Integrations (Integrations)

**Directory:** [`senor-platform/Integrations/`](senor-platform/Integrations/)

| File | Responsibility | Key Types |
|------|---------------|-----------|
| [`HTTPClient.swift`](senor-platform/Integrations/HTTPClient.swift:5) | Base HTTP infrastructure | `HTTPClient`, `HTTPClient.Configuration`, `AuthToken` |
| [`DeviantArtClient.swift`](senor-platform/Integrations/DeviantArtClient.swift:1) | DeviantArt API | `DeviantArtClient` |
| [`PatreonClient.swift`](senor-platform/Integrations/PatreonClient.swift:1) | Patreon API | `PatreonClient` |

---

## ⏰ Scheduling (SchedulerCore)

**Directory:** [`senor-platform/SchedulerCore/`](senor-platform/SchedulerCore/)

| File | Responsibility | Key Types |
|------|---------------|-----------|
| [`SchedulerEngine.swift`](senor-platform/SchedulerCore/SchedulerEngine.swift:8) | Task scheduling engine | `SchedulerEngine` |
| [`ScheduleSpec.swift`](senor-platform/SchedulerCore/ScheduleSpec.swift:1) | Schedule DSL/compiler | `ScheduleSpec`, `ScheduleCompiler`, `ScheduleKind` |

---

## ⚙️ Task Engine (TaskEngine)

**Directory:** [`senor-platform/TaskEngine/`](senor-platform/TaskEngine/)

| File | Responsibility | Key Types |
|------|---------------|-----------|
| [`TaskExecutionPipeline.swift`](senor-platform/TaskEngine/TaskExecutionPipeline.swift:5) | Task execution orchestration | `TaskExecutionPipeline` |
| [`ApprovalService.swift`](senor-platform/TaskEngine/ApprovalService.swift:1) | Approval workflow | `ApprovalService` |
| [`PublicationService.swift`](senor-platform/TaskEngine/PublicationService.swift:1) | Multi-platform publishing | `PublicationService` |
| [`ContentVersioningService.swift`](senor-platform/TaskEngine/ContentVersioningService.swift:1) | Content revisions | `ContentVersioningService` |
| [`TaskSchemaValidator.swift`](senor-platform/TaskEngine/TaskSchemaValidator.swift:1) | JSON Schema validation | `TaskSchemaValidator` |

---

## 💽 Cache Layer (CacheLayer)

**Directory:** [`senor-platform/CacheLayer/`](senor-platform/CacheLayer/)

| File | Responsibility | Key Types |
|------|---------------|-----------|
| [`CacheService.swift`](senor-platform/CacheLayer/CacheService.swift:1) | API response caching | `CacheService` |

---

## 🏃 Worker Runtime (WorkerRuntime)

**Directory:** [`senor-platform/WorkerRuntime/`](senor-platform/WorkerRuntime/)

| File | Responsibility | Key Types |
|------|---------------|-----------|
| [`WorkerProcessManager.swift`](senor-platform/WorkerRuntime/WorkerProcessManager.swift:29) | External process management | `WorkerProcessManager`, `ProcessResult`, `ProcessExit` |

---

## 🏷️ Agent Naming (AgentNaming)

**Directory:** [`senor-platform/AgentNaming/`](senor-platform/AgentNaming/)

| File | Responsibility | Key Types |
|------|---------------|-----------|
| [`AgentNamingService.swift`](senor-platform/AgentNaming/AgentNamingService.swift:1) | Unique name generation | `AgentNamingService`, `NameCategory`, `GeneratedName` |

---

## 🖥️ User Interface (Views)

**Directory:** [`senor-platform/Views/`](senor-platform/Views/)

| File | Responsibility | Key Types |
|------|---------------|-----------|
| [`ContentView.swift`](senor-platform/ContentView.swift:11) | Root view | `ContentView`, `ContentViewModel` |
| [`MainContentView.swift`](senor-platform/Views/MainContentView.swift:1) | Dashboard content | `MainContentView` |
| [`SidebarView.swift`](senor-platform/Views/SidebarView.swift:1) | Navigation sidebar | `SidebarView` |
| [`InspectorView.swift`](senor-platform/Views/InspectorView.swift:1) | Details panel | `InspectorView` |
| [`NewAgentView.swift`](senor-platform/Views/NewAgentView.swift:1) | Create agent modal | `NewAgentView` |
| [`NewTaskView.swift`](senor-platform/Views/NewTaskView.swift:1) | Create task modal | `NewTaskView` |
| [`JSONEditorView.swift`](senor-platform/Views/JSONEditorView.swift:1) | JSON editing | `JSONEditorView` |
| [`SheetViews.swift`](senor-platform/Views/SheetViews.swift:1) | Settings sheets | `SettingsView` |

### View Components

**Directory:** [`senor-platform/Views/Components/`](senor-platform/Views/Components/)

| File | Responsibility | Key Types |
|------|---------------|-----------|
| [`AsyncActionButton.swift`](senor-platform/Views/Components/AsyncActionButton.swift:1) | Async button with loading state | `AsyncActionButton` |
| [`ConfirmationDialog.swift`](senor-platform/Views/Components/ConfirmationDialog.swift:1) | Confirmation dialogs | `ConfirmationDialog` |
| [`ContentThumbnail.swift`](senor-platform/Views/Components/ContentThumbnail.swift:1) | Content preview thumbnails | `ContentThumbnail` |

---

## 🔄 Data Flow Paths

### Task Creation Flow
```
NewTaskView → ContentViewModel → TaskRepository → Database
                    ↓
              TaskScheduleRepository (if scheduled)
```

### Task Execution Flow
```
SchedulerEngine → TaskExecutionPipeline → WorkerProcessManager → External Process
                                              ↓
TaskRunRepository ← GeneratedContentRepository ← ApprovalQueueRepository
```

### Content Approval Flow
```
MainContentView → ContentViewModel → ApprovalService → ApprovalQueueRepository
                                          ↓
                                    PublicationService → Integrations
```

### Agent Creation Flow
```
NewAgentView → ContentViewModel → AgentNamingService → AgentRepository → Database
```

---

## 📊 Dependency Graph Summary

```
Views → ViewModels → Services → Repositories → DatabaseManager → GRDB
  ↑        ↑           ↑           ↑              ↑
  └────────┴───────────┴───────────┴──────────────┘
              DependencyContainer (provides all dependencies)

AgentTools → ToolProtocols → Integrations
      ↓
WorkerRuntime (spawns processes)

SchedulerCore → TaskEngine → WorkerRuntime
```

---

## 🔍 Quick Reference by Feature

| Feature | Files Involved |
|---------|---------------|
| **Create Agent** | [`NewAgentView.swift`](senor-platform/Views/NewAgentView.swift:1) → [`ContentViewModel.createAgent()`](senor-platform/ContentView.swift:355) → [`AgentNamingService.swift`](senor-platform/AgentNaming/AgentNamingService.swift:1) → [`AgentRepository`](senor-platform/DataLayer/RepositoryProtocols.swift:4) |
| **Schedule Task** | [`NewTaskView.swift`](senor-platform/Views/NewTaskView.swift:1) → [`TaskRepository`](senor-platform/DataLayer/RepositoryProtocols.swift:16) + [`TaskScheduleRepository`](senor-platform/DataLayer/RepositoryProtocols.swift:27) → [`SchedulerEngine`](senor-platform/SchedulerCore/SchedulerEngine.swift:8) |
| **Run Task** | [`SchedulerEngine`](senor-platform/SchedulerCore/SchedulerEngine.swift:8) → [`TaskExecutionPipeline.execute()`](senor-platform/TaskEngine/TaskExecutionPipeline.swift:37) → [`WorkerProcessManager.spawn()`](senor-platform/WorkerRuntime/WorkerProcessManager.swift:69) |
| **Approve Content** | [`MainContentView`](senor-platform/Views/MainContentView.swift:1) → [`ContentViewModel.approveContent()`](senor-platform/ContentView.swift:424) → [`ApprovalService`](senor-platform/TaskEngine/ApprovalService.swift:1) |
| **Publish Content** | [`ApprovalService`](senor-platform/TaskEngine/ApprovalService.swift:1) → [`PublicationService`](senor-platform/TaskEngine/PublicationService.swift:1) → [`DeviantArtClient`](senor-platform/Integrations/DeviantArtClient.swift:1) / [`PatreonClient`](senor-platform/Integrations/PatreonClient.swift:1) |
| **Generate Image** | [`AgentRunner`](senor-platform/AgentTools/AgentRunner.swift:5) → [`ComfyUITool.execute()`](senor-platform/AgentTools/ComfyUITool.swift:62) → ComfyUI API |

---

*Directory generated from source analysis on 2026-04-10*
