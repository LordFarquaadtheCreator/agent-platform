# DeviantArt Feature

## Architecture

OAuth-integrated gallery browser with sta.sh stack management.

## Key Components

| Component | File | Purpose |
|-----------|------|---------|
| Screen | `DeviantArtScreen.swift` | Main view with gallery + stash |
| Model | `DeviantArtModel.swift` | OAuth flow, API client wrapper |
| Detail Panel | `Components/DeviationDetailPanel.swift` | Inspector content |
| Providers | `DeviantArtProviders.swift` | MainContentProvider + InspectorContentProvider |

## OAuth Flow

See root `._agents.md` for full DeviantArt OAuth lessons learned.

Quick reference:
- PKCE verifier persisted to UserDefaults before browser opens
- Callback handled via `senorplatform://oauth/deviantart`
- Token refresh on 401 responses

## Components

- `StatPill` - Metric display (views, watchers, deviations)
- `StatItem` - Inline stats for deviation cards
- `TagPill` - Tag chips with FlowLayout
- `CategoryBadge` - Folder category indicator
- `FlowLayout` - Wraps tags in detail panel

## Design System Compliance

- Uses AppText, AppCard, AppVStack from SharedUI
- All spacing via AppTheme.Spacing
- All fonts via AppTheme.Typography
- No raw Color literals (use ColorToken)
