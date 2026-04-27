# Approvals Feature

Content approval workflow. Approve or reject generated content before publication.

## Key Files

| File | Purpose |
|------|---------|
| `ApprovalsFeature.swift` | Approval queue list with approve/reject actions |

## Flow

1. Task execution generates content with `status = pending`
2. Content appears in approval queue
3. User approves → status becomes `approved` → eligible for publication
4. User rejects → status becomes `rejected`

## Related

- Service: `TaskEngine/ApprovalService.swift`
- Publication: `TaskEngine/PublicationService.swift`
