# App Core (Legacy)

**Location:** `senor-platform/AppCore/`

## Scope

Legacy compatibility layer. Error handling, logging, events, keychain, settings enums.

## Key Files

| File | Responsibility |
|------|----------------|
| `DependencyContainer.swift` | Temporary service locator shim |
| `ErrorHandling.swift` | App error types |
| `Logging.swift` | Legacy logging |
| `EventBus.swift` | Legacy event coordination |
| `KeychainManager.swift` | Secure storage |
| `Settings.swift` | Settings keys/enums |
| `StatusEnums.swift` | Task/status enums |

## Rules

- `sharedContainer` is MIGRATION-ONLY
- New code uses explicit dependencies via bootstrap
- Only `AppBootstrap` and `AgentKitServiceProvider` touch container
- EventBus retained for backward compat only

## Dependencies

- Can import: Core, Domain
- Can be imported by: Infrastructure (temporarily), Application

## Migration Path

1. Move services to explicit injection in bootstrap
2. Remove container registrations
3. Delete container once fully migrated
