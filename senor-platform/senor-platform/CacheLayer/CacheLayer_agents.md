# CacheLayer

Application-level caching for remote data and integration responses.

## Key Files

| File | Purpose |
|------|---------|
| `CacheService.swift` | Generic cache with TTL eviction |

## Responsibilities

- Caches DeviantArt gallery, profile, and Patreon campaign data.
- TTL-based invalidation prevents stale data.
- Used by integration clients to reduce API calls.

## Rules

- Cache keys use namespaced format: `da:gallery:{username}:{offset}`.
- Do not cache sensitive credentials or tokens.
