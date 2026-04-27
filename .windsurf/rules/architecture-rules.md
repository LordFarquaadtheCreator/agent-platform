# Architecture Enforcement Rules

## Dependency Direction Rules

### Rule: Domain Purity
- **Scope**: `senor-platform/Domain/`
- **Enforcement**: Domain must only import Foundation
- **Forbidden imports**: SwiftUI, GRDB, any external client library
- **Rationale**: Domain models are pure business logic, no framework coupling

### Rule: SharedUI Isolation
- **Scope**: `senor-platform/SharedUI/`
- **Enforcement**: Presentation only, no data access
- **Forbidden imports**: Application, Domain (except types), DataLayer, any repository
- **Rationale**: UI components are reusable and framework-agnostic

### Rule: Feature Layer Boundaries
- **Scope**: `senor-platform/Features/`
- **Enforcement**: Features import Application (use cases), Domain, Core, SharedUI
- **Forbidden imports**: DataLayer, GRDB, direct repository access
- **Rationale**: Features consume business logic, not persistence

### Rule: Infrastructure Separation
- **Scope**: `senor-platform/TaskEngine/`, `senor-platform/SchedulerCore/`, `senor-platform/Integrations/`, `senor-platform/WorkerRuntime/`, `senor-platform/CacheLayer/`, `senor-platform/AgentTools/`
- **Enforcement**: Services import Domain + Core only
- **Forbidden imports**: Application, Features, SharedUI, SwiftUI
- **Rationale**: Infrastructure serves domain, not UI

## Code Quality Rules

### Rule: No Globals in New Code
- **Scope**: All new code
- **Enforcement**: Use explicit dependency injection
- **Exception**: Legacy compatibility in AppCore/
- **Rationale**: Testability and clear dependencies

### Rule: MVVM Pattern
- **Scope**: `senor-platform/Features/`
- **Enforcement**: FeatureModel owns state, delegates to UseCases
- **Forbidden**: Business logic in Views, repository access in Models
- **Rationale**: Separation of concerns

### Rule: Navigation Separation
- **Scope**: `senor-platform/Features/`
- **Enforcement**: Navigation state in AppRouter, not FeatureModels
- **Rationale**: Single source of truth for navigation

## Naming Conventions

### Files
- Feature views: `XxxFeature.swift`
- Feature models: `XxxModel.swift`
- Use cases: `XxxUseCase.swift` or `XxxUseCases.swift`
- Repositories: `XxxRepository.swift` (protocol), `XxxRepositoryImpl.swift` (implementation)
- Records: `XxxRecord.swift`

### Types
- Models: `@MainActor class XxxModel: ObservableObject`
- Use cases: `struct XxxUseCase`
- Domain models: `struct Xxx` or `enum Xxx`
- Records: `struct XxxRecord: Codable, FetchableRecord, PersistableRecord`

## Import Order

```swift
// 1. Framework imports
import Foundation
import SwiftUI

// 2. External library imports
import GRDB

// 3. Module imports (internal)
import Core
import Domain
import Application
import SharedUI
```
