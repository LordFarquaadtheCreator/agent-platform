---
description: AI Integration Test Dependencies - Run tests when these files change
---

# AI Integration Test Dependencies

## Test Files
- `senor-platform/senor-platformTests/AIServiceTests.swift` - Base SSE and model tests
- `senor-platform/senor-platformTests/AIIntegrationTests.swift` - Comprehensive integration tests

## Source Files (Trigger Test Run)

### Core AI Service
| File | Tests Cover |
|------|-------------|
| `Infrastructure/AIService/AIClient.swift` | AIClientTests, StreamingLogicTests, ResponseIDTrackingTests |
| `Infrastructure/AIService/AIModels.swift` | ChatRequestEncodingTests, ChatResponseDecodingTests, ChatMessageTests, MessageRoleTests |

### AI Chat Feature
| File | Tests Cover |
|------|-------------|
| `Features/AIChat/AIChatViewModel.swift` | AIChatViewModelTests (if exists) |
| `Features/AIChat/AIChatView.swift` | Preview validation |

### Context & History
| File | Tests Cover |
|------|-------------|
| `Application/ContextExtractor.swift` | Context extraction validation |
| `DataLayer/ChatHistoryStore.swift` | ChatHistoryMockStoreTests |

## Running Tests Locally

```bash
cd /Users/farquaad/agent-platform-ai-chat/senor-platform

# All AI tests
xcodebuild test -project senor-platform.xcodeproj -scheme senor-platform -destination 'platform=macOS' -only-testing:senor-platformTests/AIServiceTests -only-testing:senor-platformTests/AIIntegrationTests 2>&1 | xcbeautify

# Specific test class
xcodebuild test -project senor-platform.xcodeproj -scheme senor-platform -destination 'platform=macOS' -only-testing:senor-platformTests/AIClientTests 2>&1 | xcbeautify
```

## CI Integration

GitHub Actions workflow: `.github/workflows/ai-integration-tests.yml`

Runs automatically on push/PR to:
- `Infrastructure/AIService/**`
- `Features/AIChat/**`
- `Application/ContextExtractor.swift`
- `DataLayer/ChatHistoryStore.swift`
- Test files themselves

## Adding New Dependencies

1. Update this file with new source → test mapping
2. Add path to `.github/workflows/ai-integration-tests.yml` `on.push.paths`
3. Add test class to the `-only-testing:` list if new
