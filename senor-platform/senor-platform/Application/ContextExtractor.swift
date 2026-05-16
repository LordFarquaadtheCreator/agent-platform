import Foundation

// MARK: - Context Extractor

@MainActor
public final class ContextExtractor {
    private let maxContextTokens = 4000
    private let maxHistoryMessages = 15

    public init() {}

    public func extractContext(
        for section: AppSection,
        workspace: WorkspaceModel,
        router: AppRouter
    ) -> String {
        var context: [String: Any] = [:]
        context["section"] = section.rawValue

        switch section {
        case .dashboard:
            context["dashboard"] = extractDashboard(workspace.dashboardViewModel)

        case .agents:
            context["agents"] = extractAgents(workspace.agentsViewModel, router: router)

        case .tasks:
            context["tasks"] = extractTasks(workspace.tasksViewModel, router: router)

        case .content:
            context["content"] = extractContent(workspace.contentViewModel, router: router)

        case .approvals:
            context["approvals"] = extractApprovals(workspace.approvalsViewModel)

        case .deviantArt:
            context["deviantArt"] = extractDeviantArt(workspace.deviantArtViewModel, router: router)

        case .patreon:
            context["patreon"] = extractPatreon(workspace.patreonViewModel, router: router)

        case .comfyUI:
            context["comfyUI"] = extractComfyUI(workspace.comfyUIViewModel)

        case .tools:
            context["tools"] = extractTools()

        case .settings:
            context["settings"] = extractSettings(workspace.settingsViewModel)
        }

        // Serialize to JSON
        guard let jsonData = try? JSONSerialization.data(
            withJSONObject: context, options: [.prettyPrinted, .sortedKeys]
        ),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return "{}"
        }
        // Rough estimation: 4 characters ≈ 1 token.

        // Truncate if too large
        return truncateToFitTokenBudget(jsonString)
    }

    public func applySlidingWindow(to messages: [ChatMessage]) -> [ChatMessage] {
        guard messages.count > maxHistoryMessages else { return messages }
        // Keep system message + last N messages
        let systemMessages = messages.filter { $0.role == .system }
        let otherMessages = messages.filter { $0.role != .system }
        let trimmed = Array(otherMessages.suffix(maxHistoryMessages))
        return systemMessages + trimmed
    }

    // MARK: - Section Extractors

    private func extractDashboard(_ viewModel: DashboardViewModel) -> [String: Any] {
        let snapshot = viewModel.snapshot
        return [
            "activeAgentCount": snapshot.activeAgentCount,
            "pendingApprovalCount": snapshot.pendingApprovalCount,
            "scheduledTaskCount": snapshot.scheduledTaskCount,
            "publishedContentCount": snapshot.publishedContentCount,
            "recentContent": snapshot.recentContent.prefix(5).map { content in
                [
                    "id": content.id,
                    "title": content.title,
                    "status": content.status.rawValue,
                    "version": content.version,
                    "createdAt": ISO8601DateFormatter().string(from: content.createdAt)
                ]
            }
        ]
    }

    private func extractAgents(_ viewModel: AgentsViewModel, router: AppRouter) -> [String: Any] {
        [
            "selectedAgentID": router.selectedAgentID ?? "none",
            "agents": viewModel.agents.prefix(10).map { agent in
                [
                    "id": agent.id,
                    "displayName": agent.displayName,
                    "status": agent.status.rawValue,
                    "taskCount": agent.taskCount,
                    "createdAt": ISO8601DateFormatter().string(from: agent.createdAt)
                ]
            }
        ]
    }

    private func extractTasks(_ viewModel: TasksViewModel, router: AppRouter) -> [String: Any] {
        [
            "selectedTaskID": router.selectedTaskID ?? "none",
            "tasks": viewModel.tasks.prefix(10).map { task in
                [
                    "id": task.id,
                    "agentId": task.agentId,
                    "name": task.name,
                    "scheduleDescription": task.scheduleDescription,
                    "isEnabled": task.isEnabled,
                    "lastRun": task.lastRun?.ISO8601Format(),
                    "nextRun": task.nextRun?.ISO8601Format()
                ]
            },
            "availableAgents": viewModel.creationContext.agents.prefix(5).map { $0.displayName },
            "availableTaskTypes": viewModel.creationContext.taskTypes.prefix(5).map { $0.name }
        ]
    }

    private func extractContent(_ viewModel: ContentViewModel, router: AppRouter) -> [String: Any] {
        [
            "selectedContentID": router.selectedContentID ?? "none",
            "contentItems": viewModel.contentItems.prefix(10).map { content in
                [
                    "id": content.id,
                    "agentId": content.agentId,
                    "title": content.title,
                    "status": content.status.rawValue,
                    "version": content.version,
                    "createdAt": ISO8601DateFormatter().string(from: content.createdAt)
                ]
            }
        ]
    }

    private func extractApprovals(_ viewModel: ApprovalsViewModel) -> [String: Any] {
        [
            "approvals": viewModel.approvals.prefix(10).map { approval in
                [
                    "id": approval.id,
                    "contentId": approval.contentId,
                    "contentTitle": approval.contentTitle,
                    "agentName": approval.agentName,
                    "submittedAt": ISO8601DateFormatter().string(from: approval.submittedAt)
                ]
            }
        ]
    }

    private func extractDeviantArt(_ viewModel: DeviantArtViewModel, router: AppRouter) -> [String: Any] {
        var result: [String: Any] = [:]
        result["isAuthenticated"] = viewModel.isAuthenticated
        result["isConnecting"] = viewModel.isConnecting
        result["selectedDeviationID"] = router.selectedDeviationID ?? "none"

        if let profile = viewModel.profile {
            result["profile"] = [
                "username": profile.user.username,
                "stats": [
                    "watchers": profile.stats?.watchers ?? 0,
                    "friends": profile.stats?.friends ?? 0,
                    "deviations": profile.stats?.deviations ?? 0
                ]
            ]
        }

        result["deviations"] = viewModel.deviations.prefix(10).map { deviation in
            [
                "id": deviation.deviationid,
                "title": deviation.title,
                "category": deviation.category,
                "stats": [
                    "views": deviation.stats?.views ?? 0,
                    "favourites": deviation.stats?.favourites ?? 0,
                    "comments": deviation.stats?.comments ?? 0
                ]
            ]
        }

        return result
    }

    private func extractPatreon(_ viewModel: PatreonViewModel, router: AppRouter) -> [String: Any] {
        var result: [String: Any] = [:]

        // Auth and loading states
        result["authState"] = viewModel.authState.displayName
        result["isAuthenticated"] = viewModel.isAuthenticated
        result["isAnyLoading"] = viewModel.isAnyLoading
        result["hasAnyError"] = viewModel.hasAnyError

        // Loading states per section
        result["loadingStates"] = [
            "profile": viewModel.isLoadingProfile,
            "posts": viewModel.isLoadingPosts,
            "members": viewModel.isLoadingMembers,
            "tiers": viewModel.isLoadingTiers,
            "refreshingToken": viewModel.isRefreshingToken
        ]

        // Error states
        if let profileError = viewModel.profileError {
            result["profileError"] = profileError.displayMessage
        }
        if let postsError = viewModel.postsError {
            result["postsError"] = postsError.displayMessage
        }
        if let membersError = viewModel.membersError {
            result["membersError"] = membersError.displayMessage
        }
        if let tiersError = viewModel.tiersError {
            result["tiersError"] = tiersError.displayMessage
        }

        // Selection state
        result["selectedPostID"] = router.selectedPostID ?? "none"
        result["selectedMemberID"] = router.selectedMemberID ?? "none"

        // Full identity
        if let identity = viewModel.identity {
            result["identity"] = [
                "id": identity.data.id,
                "type": identity.data.type,
                "email": identity.data.attributes.email as Any,
                "firstName": identity.data.attributes.firstName as Any,
                "fullName": identity.data.attributes.fullName as Any,
                "imageUrl": identity.data.attributes.imageUrl as Any,
                "thumbUrl": identity.data.attributes.thumbUrl as Any,
                "url": identity.data.attributes.url as Any,
                "vanity": identity.data.attributes.vanity as Any
            ]
        }

        // Full campaign with stats
        if let campaign = viewModel.campaign {
            result["campaign"] = [
                "id": campaign.id,
                "type": campaign.type,
                "summary": campaign.attributes.summary as Any,
                "creationName": campaign.attributes.creationName as Any,
                "payPerName": campaign.attributes.payPerName as Any,
                "thanksMsg": campaign.attributes.thanksMsg as Any,
                "thanksVideoUrl": campaign.attributes.thanksVideoUrl as Any,
                "imageUrl": campaign.attributes.imageUrl as Any,
                "url": campaign.attributes.url as Any,
                "publishedAt": campaign.attributes.publishedAt as Any,
                "patronCount": campaign.attributes.patronCount ?? 0,
                "pledgeSum": campaign.attributes.pledgeSum ?? 0,
                "pledgeSumCurrency": campaign.attributes.pledgeSumCurrency as Any
            ]
        }

        // Full posts with content
        result["posts"] = viewModel.posts.map { post in
            var postDict: [String: Any] = [
                "id": post.id,
                "type": post.type,
                "title": post.attributes.title as Any,
                "content": post.attributes.content as Any,
                "url": post.attributes.url as Any,
                "isPaid": post.attributes.isPaid as Any,
                "isPublic": post.attributes.isPublic as Any,
                "publishedAt": post.attributes.publishedAt as Any
            ]

            // Include tier relationships if available
            if let tierIds = post.relationships?.tiers?.data?.map({ $0.id }) {
                postDict["tierIds"] = tierIds
            }
            if let campaignId = post.relationships?.campaign?.data?.id {
                postDict["campaignId"] = campaignId
            }

            return postDict
        }

        // Full members with all financial data
        result["members"] = viewModel.members.map { member in
            var memberDict: [String: Any] = [
                "id": member.id,
                "type": member.type,
                "fullName": member.attributes?.fullName as Any,
                "email": member.attributes?.email as Any,
                "patronStatus": member.attributes?.patronStatus as Any,
                "lastChargeStatus": member.attributes?.lastChargeStatus as Any,
                "lifetimeSupportCents": member.attributes?.lifetimeSupportCents as Any,
                "currentlyEntitledAmountCents": member.attributes?.currentlyEntitledAmountCents as Any
            ]

            // Include entitled tier IDs
            if let tierIds = member.relationships?.currentlyEntitledTiers?.map({ $0.id }) {
                memberDict["entitledTierIds"] = tierIds
            }

            return memberDict
        }

        // Full tiers
        result["tiers"] = viewModel.tiers.map { tier in
            [
                "id": tier.id,
                "type": tier.type,
                "title": tier.attributes.title,
                "amountCents": tier.attributes.amountCents as Any
            ]
        }

        // Selected post details (fetched fresh from API)
        if let selectedPost = viewModel.selectedPost {
            result["selectedPost"] = [
                "id": selectedPost.id,
                "title": selectedPost.attributes.title as Any,
                "content": selectedPost.attributes.content as Any,
                "url": selectedPost.attributes.url as Any,
                "isPaid": selectedPost.attributes.isPaid as Any,
                "isPublic": selectedPost.attributes.isPublic as Any,
                "publishedAt": selectedPost.attributes.publishedAt as Any,
                "isLoadingFreshDetails": viewModel.isLoadingSelectedPost
            ]
        }

        // Summary stats
        result["stats"] = [
            "totalPosts": viewModel.posts.count,
            "totalMembers": viewModel.members.count,
            "totalTiers": viewModel.tiers.count
        ]

        return result
    }

    private func extractComfyUI(_ viewModel: ComfyUIViewModel) -> [String: Any] {
        [
            "connected": viewModel.isConnected,
            "workflows": viewModel.workflows.map { $0.name },
            "executions": viewModel.executions.count,
            "queueRemaining": viewModel.queueStatus.pendingItems.count + (viewModel.queueStatus.runningItem != nil ? 1 : 0)
        ]
    }

    private func extractTools() -> [String: Any] {
        ["available": []]
    }

    private func extractSettings(_ viewModel: SettingsViewModel) -> [String: Any] {
        ["taskScriptPath": viewModel.taskScriptPath]
    }

    // MARK: - Token Management

    private func truncateToFitTokenBudget(_ jsonString: String) -> String {
        // Rough estimation: 4 characters ≈ 1 token
        let estimatedTokens = jsonString.count / 4

        guard estimatedTokens > maxContextTokens else {
            return jsonString
        }

        // Simple truncation: remove array items until under budget
        // In production, would use smarter summarization
        let ratio = Double(maxContextTokens) / Double(estimatedTokens)
        let targetLength = Int(Double(jsonString.count) * ratio * 0.9) // 90% to be safe

        if targetLength < jsonString.count {
            let index = jsonString.index(jsonString.startIndex, offsetBy: targetLength)
            return String(jsonString[..<index]) + "\n... (truncated)"
        } else {
            return jsonString
        }
    }
}

// MARK: - Date Formatting Helper

private extension Date {
    func ISO8601Format() -> String {
        ISO8601DateFormatter().string(from: self)
    }
}
