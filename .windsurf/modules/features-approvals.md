# Approvals Feature

**Location:** `senor-platform/Features/Approvals/`

## Scope

Content approval workflow UI: pending approvals, review, approve/reject actions.

## Key Files

| File | Responsibility |
|------|----------------|
| `ApprovalsFeature.swift` | Approval queue view |
| `ApprovalsModel.swift` | Approval state |

## Rules

- Shows pending approval queue
- Side-by-side diff/preview for review
- Approve/reject actions with optional comments
- Delegates to ApprovalService via use case

## Dependencies

- Imports: SwiftUI, Domain, Application, Core, SharedUI
