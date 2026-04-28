# Views

**Deprecated**: Legacy view layer. Being migrated to `Features/` and `SharedUI/`.

## Migration Status

| Legacy View | Replacement |
|-------------|-------------|
| `MainContentView.swift` | `Features/AppShell/AppShellView.swift` |
| `SidebarView.swift` | `Features/AppShell/AppShellView.swift` |
| `InspectorView.swift` | Feature-specific inspector providers |
| `ToastView.swift` | Toast modifier in `AppShellView` |
| `ConfirmationDialog.swift` | `SharedUI/AppComponents.swift` (move planned) |

## Rules

- Do not add new views here.
- All new UI belongs in `Features/` or `SharedUI/`.
- These files exist only as temporary compatibility shims.
