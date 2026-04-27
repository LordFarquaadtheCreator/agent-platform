# Integrations

**Location:** `senor-platform/Integrations/`

## Scope

External API clients: HTTP foundation, DeviantArt, Patreon OAuth.

## Key Files

| File | Responsibility |
|------|----------------|
| `HTTPClient.swift` | Foundation for all HTTP calls |
| `DeviantArtClient.swift` | DeviantArt API + OAuth |
| `PatreonClient.swift` | Patreon API + OAuth |
| `OAuth/` | OAuth flow handlers |

## Rules

- All HTTP through HTTPClient with retries
- OAuth flows are secure, token refresh handled
- Clients validate responses, throw typed errors
- Rate limiting respected

## Dependencies

- Imports: Foundation, Core
- Must NOT import: SwiftUI (OAuth UI in Features layer)
