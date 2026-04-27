---
description: How to add a new feature to Senor Platform
---

# Feature Development Workflow

## 1. Domain First

- Add domain model to `Domain/AppModels.swift` or new file in `Domain/`
- Define request/response types
- Keep pure structs, no SwiftUI/GRDB

## 2. Data Layer

- Add GRDB record in `DataLayer/Records.swift` (or new file)
- Add migration in `DataLayer/DatabaseManager.swift`
- Add repository protocol in `DataLayer/RepositoryProtocols.swift`
- Implement repository in `DataLayer/RepositoryImplementations.swift`

## 3. Application Layer

- Add mapper in `Application/AppMappers.swift`
- Add use case in `Application/AppUseCases.swift`
- Register repository/use case in `Application/AppBootstrap.swift`

## 4. UI Layer

- Create feature folder under `Features/`
- Add `XxxFeature.swift` (main view)
- Add `XxxModel.swift` (@MainActor, ObservableObject)
- Add `Agents.md` describing the feature
- Build with SharedUI components

## 5. Design System Compliance

- [ ] All text uses `AppText`, not raw `.font()` or `.foregroundStyle()`
- [ ] All spacing uses `AppTheme.Spacing`, not raw `.padding(N)`
- [ ] All colors use `AppTheme.ColorToken`, not raw `Color.blue` or `.tint()`
- [ ] All containers use `AppSurface`/`AppCard`, not raw `.background().cornerRadius().shadow()`
- [ ] All list rows use `AppListRow`
- [ ] All screen padding uses `.appScreenPadding()`
- [ ] Run `swiftlint` — zero violations
- [ ] If a needed token or component is missing, add it to `Core/` or `SharedUI/` first

## 6. Architecture Checklist

- [ ] Domain type has no persistence imports
- [ ] Record has no domain/UI imports
- [ ] Use case has no SwiftUI imports
- [ ] Feature model delegates to use cases
- [ ] No globals in feature code
