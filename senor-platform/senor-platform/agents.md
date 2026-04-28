# senor-platform

SwiftUI macOS app for agent management. Core directories: AppCore, DataLayer, AgentKit, TaskEngine, SchedulerCore, Features, Integrations.

## DeviantArt OAuth Integration - Lessons Learned

### Common Mistakes & Solutions

#### 1. Multiple App Instances on OAuth Callback
**Problem:** Using `WindowGroup` causes macOS to launch new app instances when handling URL scheme callbacks (`senorplatform://oauth/deviantart`).

**Solution:** Use `Window` with `handlesExternalEvents` for single-window apps:
```swift
Window("Senor Platform", id: "main") {
    ContentView()
}
.handlesExternalEvents(matching: ["senorplatform"])
```

#### 2. OAuth State/Verifier Persistence
**Problem:** App may be backgrounded/killed during browser OAuth flow, losing in-memory state.

**Solution:** Persist PKCE verifier and state to UserDefaults immediately:
```swift
UserDefaults.standard.set(pkce.verifier, forKey: "deviantArt.pendingCodeVerifier")
UserDefaults.standard.set(state, forKey: "deviantArt.pendingState")
// Also keep in memory as backup
pendingCodeVerifier = pkce.verifier
pendingState = state
```

#### 3. Stale Auth Token After Disconnect
**Problem:** `disconnect()` clears Keychain but client retains in-memory token, causing auth errors on reconnect.

**Solution:** Explicitly clear client token:
```swift
func disconnect() throws {
    // ... clear settings from Keychain ...
    client?.clearAuthToken()  // Critical!
    isAuthenticated = false
}
```

#### 4. OAuth Scope Requirements
**Problem:** DeviantArt returns 404 for `/stash/contents` endpoint even with valid token.

**Root Cause:** DeviantArt API documentation is ambiguous. Tested endpoints:
- `/stash/contents` → 404
- `/stash` → 404
- Correct endpoint unclear; may require different scope or doesn't exist for public API

**Solution:** Stub endpoint and make non-fatal:
```swift
public func getStashContents(...) async throws -> StashContentsResponse {
    // Stub: return empty until correct endpoint identified
    return StashContentsResponse(results: [], hasMore: false, nextOffset: nil)
}
```

In load(), wrap stash fetch to not fail entire load:
```swift
do {
    let stashResult = try await client.getStashContents(limit: 24)
    stashStacks = stashResult.results
} catch {
    print("Stash fetch skipped: \(error)")
    stashStacks = []  // Non-fatal
}
```

#### 5. URL Callback Handling in SwiftUI
**Problem:** `onOpenURL` modifier only works reliably in specific view hierarchy locations.

**Solution:** Place at root content view level:
```swift
ContentView()
    .onOpenURL { url in
        guard url.scheme == "senorplatform",
              url.host == "oauth",
              url.path == "/deviantart" else { return }
        Task {
            await workspace.deviantArtModel.handleCallback(url: url)
        }
    }
```

### DeviantArt API Endpoints (Verified Working)

| Endpoint | Status | Notes |
|----------|--------|-------|
| `POST /oauth2/token` | ✅ 200 | Token exchange with PKCE |
| `GET /user/profile` | ✅ 200 | User profile + stats |
| `GET /gallery/all` | ✅ 200 | Published deviations |
| `GET /stash/*` | ⚠️ 404 | Endpoint unclear; stubbed |

### OAuth Flow Implementation

1. **Start Connection:** Generate PKCE (verifier + challenge), persist to UserDefaults, build auth URL
2. **Browser Opens:** User authorizes on DeviantArt
3. **Callback:** App receives `senorplatform://oauth/deviantart?code=...&state=...`
4. **Verify State:** Match against stored (UserDefaults or memory)
5. **Token Exchange:** POST to `/oauth2/token` with code + verifier
6. **Save Token:** Store access/refresh tokens to Keychain
7. **Load Data:** Fetch profile, gallery (stash stubbed)

### Key Files

- `Features/DeviantArt/DeviantArtModel.swift` - OAuth flow, state management
- `Features/DeviantArt/DeviantArtScreen.swift` - UI with image previews
- `Integrations/DeviantArtClient.swift` - API client, endpoints
- `senor_platformApp.swift` - Window configuration for URL handling
