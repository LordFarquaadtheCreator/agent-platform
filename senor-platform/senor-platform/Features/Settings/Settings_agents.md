# Settings Feature

Integration credentials and app preferences.

## Key Files

| File | Purpose |
|------|---------|
| `SettingsFeature.swift` | Main settings form with sections |
| `SettingsSheetView.swift` | Modal sheet wrapper |

## Sections

1. **DeviantArt**: Client ID, Secret, OAuth connect
2. **Patreon**: Access token, campaign selection
3. **ComfyUI**: Server URL, timeout
4. **General**: Launch at login, notifications, log level

## Security

- Credentials stored in `Keychain` via `SettingsService`
- Non-sensitive config in `UserDefaults`
- OAuth flows open browser, callback via URL scheme
