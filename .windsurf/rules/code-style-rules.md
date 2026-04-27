# Code Style Rules

## Swift Style

### Formatting
- 4 spaces indentation
- 120 character line limit
- Opening brace on same line
- Trailing closures for single-expression closures

### Access Control
- Default to `internal`, be explicit with `public`/`private`
- `private` for implementation details
- `fileprivate` only when necessary

### Properties
- Use `let` for immutable values
- Lazy initialization for expensive properties
- Computed properties for derived values

### Functions
- Explicit `self.` only in closures or when required
- Trailing closure syntax preferred
- `@discardableResult` for side-effect-only functions

## Comments

### Required Comments
- Why, not what (code explains what)
- Non-obvious behavior
- Platform/version workarounds
- Performance considerations

```swift
// debounce to avoid hammering API
// offset accounts for sticky header
// iOS 15 workaround for navigation
```

### Forbidden Comments
- Comments that describe obvious code
- Comments with emojis
- Comments stating "fixed bug" without context

## Error Handling

### Typed Errors
- Use custom error enums, not strings
- Error cases describe what went wrong

```swift
enum RepositoryError: Error {
    case notFound(id: UUID)
    case saveFailed(underlying: Error)
    case invalidState(expected: String, actual: String)
}
```

### Async/Await
- Use `async throws`, not callback-based
- Propagate errors, don't swallow
- Log at appropriate levels

## SwiftUI Specific

### File Organization (ENFORCED)
- **One primary view per file** - Screen files contain ONLY the main screen view
- **Supporting views extracted** - Subviews go in `+ SupportingViews` extension in same file OR separate file
- **Maximum 400 lines per view file** - Split when exceeded
- **Feature folder structure**:
  ```
  Features/FeatureName/
    FeatureNameScreen.swift      - Main screen only
    FeatureNameModel.swift       - Feature model
    + Views/                    - If many subviews
      FeatureCard.swift
      FeatureRow.swift
  ```

### View Structure
- Small, focused views
- Extract subviews early
- Use `@ViewBuilder` for conditional content
- Environment for dependency injection
- **Maximum 8 subview references per body** - Extract when exceeded

### State Management
- `@State` for view-local state
- `@StateObject` for feature models
- `@ObservedObject` for injected models
- `@Binding` for two-way parent-child

### Previews (REQUIRED)
- **ALL view structs MUST have `#Preview`** - No exceptions
- Place preview at end of file in `// MARK: - Previews` section
- Multiple preview configurations (light/dark, sizes)
- Preview with sample data

```swift
struct AgentScreen: View {
    @ObservedObject var model: AgentModel
    // ...
}

// MARK: - Supporting Views

private struct AgentRow: View {
    let agent: Agent
    // ...
}

// MARK: - Previews

#Preview {
    AgentScreen(model: .preview)
}

#Preview("Dark") {
    AgentScreen(model: .preview)
        .preferredColorScheme(.dark)
}
```
