# Contributing to Senor Platform

Thank you for your interest in contributing to Senor Platform. This document provides guidelines for contributing to the project.

## Development Setup

1. Fork the repository
2. Clone your fork:
```bash
git clone https://github.com/yourusername/senor-app.git
cd senor-app
```

3. Open the project in Xcode:
```bash
open senor-platform.xcodeproj
```

4. Build the project (⌘B) to ensure dependencies resolve correctly

## Code Style and Conventions

### Swift Style

- Follow Swift API Design Guidelines
- Use meaningful variable and function names
- Prefer `let` over `var` when possible
- Use guard statements for early exits
- Mark functions as `@MainActor` when they must run on the main thread

### Architecture Guidelines

#### Layer Separation

The codebase follows strict one-way dependency rules:

```
Features → Application + Domain + SharedUI + Core
Application → Domain + Core + Infrastructure abstractions
Infrastructure → Domain + Core
Domain → (no external dependencies)
```

**Rules:**
- Domain models must not import SwiftUI, GRDB, or any external dependencies
- Feature code must not directly access persistence records
- Use Application layer mappers to convert records to domain models
- Infrastructure code must depend only on Domain and Core

#### Dependency Injection

- Use constructor injection for all dependencies
- Pass dependencies via `AppDependencies` bag
- Do not use the legacy `DependencyContainer` for new code
- Register services in `AppBootstrap.swift`

#### State Management

- Feature models must be `@MainActor ObservableObject`
- Use `@Published` properties for reactive state
- Repositories should be async-only (no Combine)
- Navigation state lives in `AppRouter`, not feature models

### Design System

The project uses SwiftLint-enforced design tokens. Do not use raw styling:

**❌ Incorrect:**
```swift
Text("Hello")
    .font(.body)
    .foregroundColor(.blue)
    .padding(8)
    .cornerRadius(4)
```

**✅ Correct:**
```swift
AppText("Hello", style: .body)
    .foregroundColor(AppTheme.ColorToken.primary)
    .padding(AppTheme.Spacing.medium)
    .cornerRadius(AppTheme.CornerRadius.small)
```

### Comments

- Add comments only to explain **why**, not **what**
- Non-obvious behavior deserves explanation
- Delete comments that describe what the code already makes obvious

**Good:**
```swift
// debounce to avoid hammering API
// offset accounts for sticky header
// iOS 15 workaround
```

**Bad:**
```swift
// centered the div
// fixed the bug
```

## Testing

### Running Tests

Run tests from Xcode (⌘U) or via command line:

```bash
xcodebuild test -scheme senor-platform -destination 'platform=macOS'
```

### Test Guidelines

- Focus on architectural boundary tests
- Test use case integration
- Mock repositories and services for feature tests
- Use `PreviewMocks.swift` for SwiftUI preview data

### Test Coverage Priorities

1. Use case logic (Application layer)
2. Repository implementations (DataLayer)
3. Service layer (TaskEngine, Integrations)
4. Architectural boundary enforcement

## Commit Conventions

### Commit Message Format

Use conventional commits with one-line messages:

```
feat: add ComfyUI workflow execution
fix: resolve OAuth token refresh issue
refactor: extract view models from views
docs: update API integration documentation
test: add approval service unit tests
```

### Commit Rules

- One unit of work per commit
- Keep messages concise (one line)
- Focus on "why" not "what"
- Do not commit sensitive data (tokens, secrets)

### Creating Commits

1. Stage files: `git add <files>`
2. Commit with message:
```bash
git commit -m "feat: your feature description"
```

## Pull Request Process

1. Create a new branch from `main`:
```bash
git checkout -b feature/your-feature-name
```

2. Make your changes following the guidelines above
3. Run tests and ensure they pass
4. Commit your changes with conventional commit messages
5. Push to your fork:
```bash
git push origin feature/your-feature-name
```

6. Create a pull request with:
   - Clear description of changes
   - Reference related issues
   - Screenshots for UI changes (if applicable)

### PR Review Checklist

- [ ] Code follows architecture guidelines
- [ ] Design system tokens used correctly
- [ ] Tests pass locally
- [ ] No sensitive data committed
- [ ] Comments explain "why" not "what"
- [ ] Commit messages follow conventions

## Adding New Features

### New Feature Checklist

1. **Domain Layer**: Add or update domain models in `Domain/AppModels.swift`
2. **Data Layer**: Add GRDB records and repository implementations
3. **Application Layer**: Add use cases and mappers
4. **Feature Layer**: Create view model and SwiftUI views
5. **Routing**: Update `AppRouter` if new navigation needed
6. **Bootstrap**: Register new services in `AppBootstrap.swift`
7. **Dependencies**: Add to `AppDependencies` if needed
8. **Tests**: Add architectural boundary tests
9. **Documentation**: Update README if user-facing

### New Integration Checklist

1. **Client**: Implement HTTP client in `Integrations/`
2. **OAuth**: Add OAuth flow if required (use PKCE)
3. **Models**: Add domain models for API responses
4. **Repository**: Create repository for data persistence
5. **Service**: Add service layer for business logic
6. **Feature**: Create view model and UI
7. **Settings**: Add configuration UI in Settings
8. **Tests**: Add integration tests for API client

## Known Issues and Limitations

When contributing, be aware of current limitations:

- DeviantArt stash endpoint returns 404 (stubbed as non-fatal)
- Patreon API v2 is read-only (no programmatic post creation)
- Two `@MainActor` blocks disabled in DeviantArt model pending Swift 6 fixes
- Test coverage is thin (prioritize architectural tests)

## Questions?

- Open an issue for bugs or feature requests
- Use discussions for questions or architectural proposals
- Check existing issues before creating new ones

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
