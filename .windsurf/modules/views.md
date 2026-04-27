# Views (Legacy)

**Location:** `senor-platform/Views/`

## Scope

Legacy view layer. Thin adapters preserved while new feature tree owns shell.

## Key Files

| File | Responsibility |
|------|----------------|
| `MainContentView.swift` | Legacy main content |
| `SidebarView.swift` | Legacy sidebar |
| `InspectorView.swift` | Legacy inspector |
| `JSONEditorView.swift` | JSON editing utility |
| `AgentInspectorView.swift` | Agent detail inspector |
| `TaskInspectorView.swift` | Task detail inspector |
| `TaskProgressSheet.swift` | Progress modal |
| `ApprovalReviewSheet.swift` | Approval modal |
| `CreateTaskSheet.swift` | Task creation |
| `ConnectionStatusView.swift` | Connection status |

## Rules

- Legacy adapters, being replaced by Features/
- New features should use Features/ tree
- These thin wrappers delegate to new implementation

## Dependencies

- Imports: SwiftUI, Core, Domain, Application
