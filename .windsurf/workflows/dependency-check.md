---
description: How to verify dependency direction before committing
---

# Dependency Direction Check

## Allowed Dependencies

```
Core → none (Foundation only)
Domain → Core
Application → Domain + Core + Infrastructure abstractions
Infrastructure → Domain + Core
Features → Application + Domain + Core + SharedUI
SharedUI → Core
```

## Forbidden

- Domain importing SwiftUI, GRDB, or external clients
- SharedUI importing Application, Domain, DataLayer
- Features importing DataLayer, GRDB, or repositories directly
- Infrastructure importing Application, Features, SharedUI
- Core importing anything above it

## Quick Check Commands

Search for violations in new code:

```bash
# Domain importing SwiftUI - FORBIDDEN
grep -r "import SwiftUI" senor-platform/Domain/

# Domain importing GRDB - FORBIDDEN
grep -r "import GRDB" senor-platform/Domain/

# Features importing GRDB - FORBIDDEN
grep -r "import GRDB" senor-platform/Features/

# SharedUI importing Application - FORBIDDEN
grep -r "import Application" senor-platform/SharedUI/
```

## Design System Check

Before commit, verify no raw styling leaked into Features/AppCore/Views:

```bash
# Raw .font() - FORBIDDEN outside Core/SharedUI
grep -r "\.font(" senor-platform/Features/ senor-platform/AppCore/ senor-platform/Views/

# Raw Color literals - FORBIDDEN outside Core/SharedUI
grep -r "Color\." senor-platform/Features/ senor-platform/AppCore/ senor-platform/Views/

# Raw .cornerRadius() - FORBIDDEN outside Core/SharedUI
grep -r "\.cornerRadius(" senor-platform/Features/ senor-platform/AppCore/ senor-platform/Views/

# Raw .shadow(color: - FORBIDDEN outside Core/SharedUI
grep -r "\.shadow(color:" senor-platform/Features/ senor-platform/AppCore/ senor-platform/Views/
```

## Manual Review

Before commit, verify:
1. New files follow the layer they are in
2. Import statements only reference allowed layers
3. No GRDB types leak into Feature views
4. No repository access from SharedUI components
5. No raw styling modifiers in feature/view code; all visual values trace back to `AppTheme`
