# Shared UI

**Location:** `senor-platform/SharedUI/`

## Scope

Reusable UI primitives. Presentation only. All feature code consumes these components; no raw styling in Features, AppCore, or Views.

## Key Files

| File | Responsibility |
|------|----------------|
| `AppComponents.swift` | Shared visual components |

## Component Catalog

| Component | Use Case | Tokens Used |
|---|---|---|
| `AppText(_:style:)` | All text display | `Typography`, `ColorToken` |
| `AppSurface(style:)` | Card, flat, elevated containers | `ColorToken`, `CornerRadius`, `Shadow` |
| `AppCard` | Legacy alias for `AppSurface(style: .card)` | Same as `AppSurface` |
| `AppVStack(spacing:)` | Vertical layout with semantic spacing | `Spacing` |
| `AppHStack(spacing:)` | Horizontal layout with semantic spacing | `Spacing` |
| `AppListRow` | Row wrapper in lists | `Spacing.listRowPadding` |
| `AppSectionHeader` | Section titles with optional detail + action | `Typography`, `Spacing` |
| `AppMetricCard` | Dashboard metric display | `Typography`, `Spacing`, `ColorToken` |
| `AppStatusPill` | Status badge | `Typography`, `Spacing` |
| `AppEmptyState` | Empty state placeholder | — |
| `AppFormSection(_:)` | Form section with tokenized header | `Typography` |
| `AppDivider` | Standardized divider | `ColorToken.divider` |
| `appScreenPadding()` | Screen-level padding modifier | `Spacing.screenPadding` |
| `appButtonStyle(_:)` | Standardized button styles | `ColorToken` |
| `AppIcon(_:size:)` | Standardized SF Symbol image | `Typography` |
| `AppStatusColor` | Semantic status color enum | `ColorToken` |

## Rules

- Pure presentation, no data access
- Uses Core theme tokens exclusively; no hardcoded values
- No view models, no repositories
- Reusable across all Features
- If a needed component does not exist, add it here. Never workaround with raw styling.

## Dependencies

- Imports: SwiftUI, Core
- Must NOT import: Application, Domain, DataLayer, any service
