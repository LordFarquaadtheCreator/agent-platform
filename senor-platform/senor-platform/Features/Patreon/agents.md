# Patreon Feature

## Architecture

OAuth-integrated Patreon dashboard showing posts and member list.

## Key Components

| Component | File | Purpose |
|-----------|------|---------|
| Screen | `PatreonScreen.swift` | Posts list + members list |
| Model | `PatreonModel.swift` | OAuth, API calls, caching |
| Post Detail | `PatreonPostDetailPanel.swift` | Inspector for posts |
| Member Detail | `PatreonMemberDetailPanel.swift` | Inspector for patrons |
| Providers | `PatreonProviders.swift` | Content + inspector providers |

## OAuth Flow

Similar to DeviantArt but with Patreon scopes:
- `identity` - User profile
- `campaigns` - Creator campaigns
- `members` - Patron list

## Shared Formatters

`Core/PatreonFormatters.swift` provides:
- `formatCents(Int?) -> String` - e.g., 500 -> "$5.00"
- `formatDate(String) -> String` - ISO8601 to readable
- `statusColor(String) -> Color` - patron status colors

Used by both screen and detail panels (no duplication).

## Components

- `PatreonPostDetailPanel` - Shows post content with MarkdownUI
- `PatreonMemberDetailPanel` - Shows pledge info, email, lifetime support

## Design System Compliance

- VStack/HStack with AppTheme.Spacing for layout
- AppText for all text
- AppTheme.ColorToken for colors
- AppTheme.Spacing for padding

## Previews

All Patreon previews use dependency injection with mock clients.

### Mock Client Configuration

```swift
let viewModel = previewPatreonViewModel(postCount: 5, memberCount: 3)
```

### Available Preview States

| Preview | State | Mock Configuration |
|---------|-------|---------------------|
| "Not Configured" | No credentials | `client = nil` |
| "Empty" | No posts/members | `mockPosts = [], mockMembers = []` |
| "Single" | 1 post, 1 member | `mockPosts = [1], mockMembers = [1]` |
| "Many" | 15 posts, 8 members | `mockPosts = [15], mockMembers = [8]` |
| "Selected" | Item selected | Set `router.selectedPostID` or `selectedMemberID` |
