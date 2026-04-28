# SharedUI

Reusable SwiftUI components built from `Core` design tokens. Must not reach into repositories or services.

## Key Components

| Component | File | Purpose |
|-----------|------|---------|
| `AppText` | `AppComponents.swift` | Tokenized text with style and color |
| `AppSurface` | `AppComponents.swift` | Card/flat/elevated container |
| `VStack` / `HStack` | Native SwiftUI | Use with `AppTheme.Spacing` for semantic spacing |
| `AppListRow` | `AppComponents.swift` | Row wrapper with tokenized padding |
| `AppCard` | `AppComponents.swift` | Legacy alias for `AppSurface(style: .card)` |
| `AppMetricCard` | `AppComponents.swift` | Metric display with icon, value, label |
| `AppEmptyState` | `AppComponents.swift` | `ContentUnavailableView` wrapper |
| `AppSectionHeader` | `AppComponents.swift` | Title + detail + optional action |
| `AppStatusPill` | `AppComponents.swift` | Colored capsule badge |
| `AppFormSection` | `AppComponents.swift` | Form section with tokenized header |
| `AppDivider` | `AppComponents.swift` | Tokenized divider |
| `AppScreenPadding` | `AppComponents.swift` | View modifier for screen padding |
| `AppIcon` | `AppComponents.swift` | Sized SF Symbol wrapper |
| `AIHelperField` | `AIHelperField.swift` | Text field with AI suggestion placeholder |

## Rules

- Components must only import `SwiftUI` and `Core`.
- No `@ObservedObject`, `@StateObject`, or repository references.
- All styling must use `AppTheme` tokens.
