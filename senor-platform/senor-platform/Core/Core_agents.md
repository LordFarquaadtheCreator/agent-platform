# Core

Design tokens and shared app primitives. Feature code must not define raw visual values.

## Key Files

| File | Purpose |
|------|---------|
| `AppTheme.swift` | Centralized typography, spacing, colors, corner radius, shadows, layout, icons |
| `ImageCacheService.swift` | On-disk image cache for integration thumbnails |
| `PatreonFormatters.swift` | Currency and date formatting for Patreon display |
| `RelativeDateFormatter.swift` | Human-readable relative timestamps |
| `ToastState.swift` | Shared toast message publisher |

## Design Token Rules

- `AppTheme.Typography` replaces `.font(.headline)` etc.
- `AppTheme.ColorToken` replaces `Color.blue`, `Color.red` etc.
- `AppTheme.Spacing` replaces raw `.padding(16)` etc.
- `AppTheme.CornerRadius` replaces raw `.cornerRadius(10)` etc.
- `AppTheme.Shadow` replaces raw `.shadow(...)` etc.
- Only `Core` may define raw `Color` values. All other directories consume tokens.
