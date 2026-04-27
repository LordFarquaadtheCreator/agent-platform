# AppShell

Split-view shell with sidebar, main content area, and inspector.

## Key Files

| File | Purpose |
|------|---------|
| `AppShellView.swift` | Three-pane layout: sidebar, content, inspector |
| `ContentProviders.swift` | Content provider registry for each `AppSection` |

## Layout

- Sidebar: `AppSection` navigation with icons
- Main area: `MainContentProvider` view for selected section
- Inspector: `InspectorContentProvider` detail panel for selected item
- Toolbar: Refresh, new agent/task buttons

## State

- `AppShellModel` owns initialization and sheet presentation
- `AppRouter` owns selected section and item selection
