---
description: How to add a new agent capability or tool
---

# Agent Development Workflow

## 1. Define Tool Contract

- Add protocol to `AgentKit/Tools/ToolProtocols.swift` or `AgentTools/ToolProtocols.swift`
- Define input schema, output schema, and error types
- Document the tool's purpose

## 2. Implement Tool

- Create implementation in `AgentTools/` or `AgentKit/Tools/`
- Implement as pure function: input → output
- Handle errors gracefully, throw typed errors
- No UI code in tool implementation

## 3. Register in AgentKit

- Add capability in `AgentKit/Agent/Capability.swift`
- Register tool with agent framework
- Update `AgentKitServiceProvider.swift` if needed

## 4. Update Domain

- Add capability enum case in `Domain/AppModels.swift`
- Update agent validation rules

## 5. Test

- Add unit test in `senor-platformTests/AgentKitTests/`
- Test with valid and invalid inputs
- Test error cases

## Architecture Checklist

- [ ] Tool is pure, no side effects
- [ ] Input/output clearly documented
- [ ] No SwiftUI imports in tool implementation
- [ ] Error handling is typed, not stringly
- [ ] Registered in bootstrap or provider

## Design System Compliance (if any UI changes)

- [ ] All text uses `AppText`, not raw `.font()` or `.foregroundStyle()`
- [ ] All spacing uses `AppTheme.Spacing`, not raw `.padding(N)`
- [ ] All colors use `AppTheme.ColorToken`, not raw `Color.blue` or `.tint()`
- [ ] All containers use `AppSurface`/`AppCard`, not raw `.background().cornerRadius().shadow()`
- [ ] Run `swiftlint` — zero violations
