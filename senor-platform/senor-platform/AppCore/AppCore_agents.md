# AppCore

Cross-cutting application services. Legacy `DependencyContainer` and `EventBus` retained temporarily.

## Key Files

| File | Purpose |
|------|---------|
| `AppError.swift` | Unified error enum with user-facing messages |
| `AppLogger.swift` | Categorized logging (ui, database, taskEngine, integrations) |
| `AppLogger+AgentKit.swift` | AgentKit-specific log helpers |
| `DependencyContainer.swift` | Legacy service-locator shim; do not use in new code |
| `EventBus.swift` | Legacy notification bridge; primary shell no longer depends on it |
| `SettingsService.swift` | UserDefaults + Keychain settings for all integrations |
| `Keychain.swift` | Secure credential storage wrapper |
| `ServiceProtocols.swift` | Service abstractions |
| `HTMLUtils.swift` | HTML sanitization helpers |
| `JSONUtils.swift` | JSON validation and formatting |
| `StatusColor.swift` | Status-to-color mapping |
| `StatusEnums.swift` | Runtime and workflow status definitions |

## SettingsService Notes

- Non-sensitive data → `UserDefaults`
- Tokens, secrets → `Keychain`
- Settings structs: `DeviantArtSettings`, `PatreonSettings`, `ComfyUISettings`, `GeneralSettings`

## Migration Status

`DependencyContainer` and `EventBus` are temporary. New code must use explicit constructor injection via `AppDependencies`.
