# Design System Rules

## Golden Rule

All visual styling must use `AppTheme` tokens or `SharedUI` components. Zero raw `.font()`, `.foregroundColor()`, `.foregroundStyle()`, `.background()`, `.padding()`, `.cornerRadius()`, `.shadow()`, `.tint()` in Feature, AppCore, or Views code.

## Token Usage

| Visual Property | Token Source | Example |
|---|---|---|
| Font | `AppTheme.Typography` | `AppText(value, style: .metricValue)` |
| Color | `AppTheme.ColorToken` | `AppTheme.ColorToken.accent` |
| Spacing | `AppTheme.Spacing` | `.padding(AppTheme.Spacing.medium)` |
| Radius | `AppTheme.CornerRadius` | `AppTheme.CornerRadius.card` |
| Shadow | `AppTheme.Shadow` | `AppTheme.Shadow.subtle` |
| Layout | `AppTheme.Layout` | `AppTheme.Layout.minSheetWidth` |
| Icon | `AppTheme.Icon` | `Image(systemName: AppTheme.Icon.agent)` |

## Component Usage

| Use Case | Component | Never Use |
|---|---|---|
| Text | `AppText` | `Text(...).font(...).foregroundStyle(...)` |
| Card | `AppSurface(style: .card)` or `AppCard` | `.background(...).clipShape(...).shadow(...)` |
| Row padding | `AppListRow` | `.padding(.vertical, 4)` |
| Section header | `AppSectionHeader` | Hardcoded title stack |
| Metric display | `AppMetricCard` | Custom card with `.system(size: 28)` |
| Status badge | `AppStatusPill` | Custom capsule |
| Button style | `appButtonStyle(...)` | `.tint(.red)` on buttons |
| Screen padding | `.appScreenPadding()` | `.padding(24)` |
| Divider | `AppDivider` | `Divider()` with custom color |
| Icon | `AppIcon` | Raw `Image(systemName:)` with `.font(...)` |

## Enforcement

- SwiftLint custom rules in `.swiftlint.yml` block violations at build time.
- Build fails if any forbidden modifier appears in Features/, AppCore/, or Views/.

## Extension Rule

If a needed token or component does not exist, add it to `Core/AppTheme.swift` or `SharedUI/AppComponents.swift` first. Never workaround with raw styling.

## Pre-Commit Checklist

1. Run `swiftlint`.
2. Verify zero violations across `senor-platform/`.
3. Confirm no raw styling in modified files.
