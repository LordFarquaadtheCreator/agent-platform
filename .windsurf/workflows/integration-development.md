---
description: How to add a new external API integration
---

# Integration Development Workflow

## 1. Define API Client

- Create client in `Integrations/` (e.g. `NewServiceClient.swift`)
- Use `HTTPClient.swift` as foundation
- Define request/response models
- Handle authentication (OAuth if needed)

## 2. Add OAuth (if needed)

- Add OAuth flow in `Integrations/OAuth/`
- Store tokens in Keychain via `AppCore/KeychainManager.swift`
- Handle token refresh automatically

## 3. Domain Models

- Add integration-specific models in `Domain/`
- Keep models pure, no client-specific types

## 4. Use Case

- Add publishing/fetching use case in `Application/AppUseCases.swift`
- Use repository pattern for data access

## 5. Settings UI

- Add connection UI in `Features/Settings/`
- Show connection status, disconnect option
- Handle errors gracefully

## Checklist

- [ ] Rate limiting respected
- [ ] Token refresh handled
- [ ] Error cases covered
- [ ] No client-specific types in Domain
- [ ] OAuth UI separated from client logic
