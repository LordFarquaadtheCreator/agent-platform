# Integrations

External API clients and OAuth handling. Feature models wrap these; views never call directly.

## Key Files

| File | Purpose |
|------|---------|
| `HTTPClient.swift` | Shared URLSession wrapper with request/response logging |
| `DeviantArtClient.swift` | DeviantArt API: OAuth2 PKCE, gallery, stash, publish, user profile |
| `PatreonClient.swift` | Patreon API: campaigns, posts, tiers, pledges |

## OAuth Patterns

- PKCE verifier persisted to `UserDefaults` before browser opens.
- Tokens stored in `Keychain`.
- Callback handled via `senorplatform://oauth/{provider}` in `ContentView.onOpenURL`.
- Token refresh on 401 responses.

## Known Issues

- DeviantArt `/stash/contents` returns 404; endpoint stubbed as non-fatal.
- See root `._agents.md` for full DeviantArt OAuth lessons learned.
