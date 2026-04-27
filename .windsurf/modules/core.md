# Core Layer

**Location:** `senor-platform/Core/`

## Scope

Cross-cutting primitives: design tokens, shared utilities, app-wide constants. Single source of truth for all visual values.

## Key Files

| File | Responsibility |
|------|----------------|
| `AppTheme.swift` | Colors, spacing, typography, shadows, radii, layout, icons |
| `AppUtilities.swift` | Shared non-UI helpers |

## Token Taxonomy

`AppTheme` contains 7 token namespaces. No hardcoded values exist outside this file.

| Namespace | Contains | Example |
|---|---|---|
| `Typography` | Font presets for all text roles | `Typography.headline`, `Typography.metricValue` |
| `ColorToken` | Semantic colors: backgrounds, text, status, borders | `ColorToken.accent`, `ColorToken.statusError` |
| `Spacing` | Numeric and semantic spacing constants | `Spacing.medium`, `Spacing.screenPadding` |
| `CornerRadius` | Standardized corner radii | `CornerRadius.card`, `CornerRadius.pill` |
| `Shadow` | Shadow presets and raw values | `Shadow.subtle`, `Shadow.elevated` |
| `Layout` | Screen and component dimensions | `Layout.minSheetWidth`, `Layout.sidebarMinWidth` |
| `Icon` | Centralized SF Symbol names | `Icon.agent`, `Icon.refresh` |

## Rules

- Design tokens only, no business logic
- No external dependencies beyond Foundation/SwiftUI
- Safe to import from any layer
- All visual values must be defined here; no magic numbers in other files

## Dependencies

- Imports: Foundation, SwiftUI
- Can be imported by: ALL layers
