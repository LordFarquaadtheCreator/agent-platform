# Cache Layer

**Location:** `senor-platform/CacheLayer/`

## Scope

TTL caching with persistence.

## Key Files

| File | Responsibility |
|------|----------------|
| `CacheManager.swift` | TTL cache with disk persistence |

## Rules

- TTL-based expiration
- Persistent across launches
- Thread-safe access
- Memory + disk hybrid

## Dependencies

- Imports: Foundation, Core
- Must NOT import: SwiftUI
