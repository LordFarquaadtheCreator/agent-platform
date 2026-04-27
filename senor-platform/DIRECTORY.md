# Senor Platform Directory

Quick navigation for the current application structure.

## Entry Points

| Component | File | Purpose |
| --- | --- | --- |
| App entry | [`senor_platformApp.swift`](senor-platform/senor_platformApp.swift:1) | Launches the macOS app and installs the shell model |
| Root content | [`ContentView.swift`](senor-platform/ContentView.swift:1) | Displays bootstrap/loading/error states and sheet routing |
| Shell layout | [`AppShellView.swift`](senor-platform/Features/AppShell/AppShellView.swift:1) | Split-view shell, toolbar, and inspector composition |

## Architecture Spine

| Area | Key Files |
| --- | --- |
| Application | [`AppBootstrap.swift`](senor-platform/Application/AppBootstrap.swift:1), [`AppDependencies.swift`](senor-platform/Application/AppDependencies.swift:1), [`AppRouter.swift`](senor-platform/Application/AppRouter.swift:1), [`AppShellModel.swift`](senor-platform/Application/AppShellModel.swift:1), [`AppUseCases.swift`](senor-platform/Application/AppUseCases.swift:1), [`AppMappers.swift`](senor-platform/Application/AppMappers.swift:1), [`ContextExtractor.swift`](senor-platform/Application/ContextExtractor.swift:1) |
| Domain | [`AppModels.swift`](senor-platform/Domain/AppModels.swift:1) |
| Core | [`AppTheme.swift`](senor-platform/Core/AppTheme.swift:1) |
| Shared UI | [`AppComponents.swift`](senor-platform/SharedUI/AppComponents.swift:1) |

## Features

| Feature | File |
| --- | --- |
| App shell | [`AppShellView.swift`](senor-platform/Features/AppShell/AppShellView.swift:1) |
| Dashboard | [`DashboardFeature.swift`](senor-platform/Features/Dashboard/DashboardFeature.swift:1) |
| Agents | [`AgentFeature.swift`](senor-platform/Features/Agents/AgentFeature.swift:1) |
| Tasks | [`TaskFeature.swift`](senor-platform/Features/Tasks/TaskFeature.swift:1) |
| Content | [`ContentFeature.swift`](senor-platform/Features/Content/ContentFeature.swift:1) |
| Approvals | [`ApprovalsFeature.swift`](senor-platform/Features/Approvals/ApprovalsFeature.swift:1) |
| Settings | [`SettingsFeature.swift`](senor-platform/Features/Settings/SettingsFeature.swift:1) |
| AI Chat | [`AIChatView.swift`](senor-platform/Features/AIChat/AIChatView.swift:1), [`AIChatViewModel.swift`](senor-platform/Features/AIChat/AIChatViewModel.swift:1) |

## Infrastructure

| Area | Key Files |
| --- | --- |
| Data layer | [`DatabaseManager.swift`](senor-platform/DataLayer/DatabaseManager.swift:1), [`Records.swift`](senor-platform/DataLayer/Records.swift:1), [`RepositoryProtocols.swift`](senor-platform/DataLayer/RepositoryProtocols.swift:1), [`RepositoryImplementations.swift`](senor-platform/DataLayer/RepositoryImplementations.swift:1), [`PatreonClient.swift`](senor-platform/Integrations/PatreonClient.swift:1) |
| Task engine | [`TaskExecutionPipeline.swift`](senor-platform/TaskEngine/TaskExecutionPipeline.swift:1), [`ApprovalService.swift`](senor-platform/TaskEngine/ApprovalService.swift:1), [`PublicationService.swift`](senor-platform/TaskEngine/PublicationService.swift:1), [`ContentVersioningService.swift`](senor-platform/TaskEngine/ContentVersioningService.swift:1) |
| Scheduler | [`SchedulerEngine.swift`](senor-platform/SchedulerCore/SchedulerEngine.swift:1), [`ScheduleSpec.swift`](senor-platform/SchedulerCore/ScheduleSpec.swift:1) |
| Integrations | [`HTTPClient.swift`](senor-platform/Integrations/HTTPClient.swift:1), [`DeviantArtClient.swift`](senor-platform/Integrations/DeviantArtClient.swift:1) |
| AI Service | [`AIClient.swift`](senor-platform/Infrastructure/AIService/AIClient.swift:1), [`AIModels.swift`](senor-platform/Infrastructure/AIService/AIModels.swift:1) |
| Worker runtime | [`WorkerProcessManager.swift`](senor-platform/WorkerRuntime/WorkerProcessManager.swift:1) |
| Agent tools | [`ToolProtocols.swift`](senor-platform/AgentTools/ToolProtocols.swift:1), [`AgentRunner.swift`](senor-platform/AgentTools/AgentRunner.swift:1), [`PublishingTools.swift`](senor-platform/AgentTools/PublishingTools.swift:1) |

## Legacy Compatibility

| File | Role |
| --- | --- |
| [`DependencyContainer.swift`](senor-platform/AppCore/DependencyContainer.swift:1) | Temporary service-locator shim retained for compatibility |
| [`LegacyContainerBridge.swift`](senor-platform/Application/LegacyContainerBridge.swift:1) | Single place allowed to register bootstrap-created services into the compatibility container |
| [`MainContentView.swift`](senor-platform/Views/MainContentView.swift:1), [`SidebarView.swift`](senor-platform/Views/SidebarView.swift:1), [`InspectorView.swift`](senor-platform/Views/InspectorView.swift:1) | Thin adapters preserved while the new feature tree owns the real shell |

## Tests

| Area | File |
| --- | --- |
| Unit tests | [`senor_platformTests.swift`](senor-platformTests/senor_platformTests.swift:1) |
| UI tests | [`senor_platformUITests.swift`](senor-platformUITests/senor_platformUITests.swift:1), [`senor_platformUITestsLaunchTests.swift`](senor-platformUITests/senor_platformUITestsLaunchTests.swift:1) |
