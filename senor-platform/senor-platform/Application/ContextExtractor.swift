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
        case .tools:
            context["tools"] = extractTools()
        case .settings:
            context["settings"] = extractSettings(workspace.settingsViewModel)
        }

        // Serialize to JSON
        guard let jsonData = try? JSONSerialization.data(withJSONObject: context, options: [.prettyPrinted, .sortedKeys]),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return "{}"
        }

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
        return [
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
        return [
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
        return [
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
        return [
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
                    "watchers": profile.stats.watchers,
                    "friends": profile.stats.friends,
                    "deviations": profile.stats.deviations
                ]
            ]
        }

        result["deviations"] = viewModel.deviations.prefix(10).map { deviation in
            [
                "id": deviation.deviationid,
                "title": deviation.title,
                "category": deviation.category,
                "stats": [
                    "views": deviation.stats.views,
                    "favourites": deviation.stats.favourites,
                    "comments": deviation.stats.comments
                ]
            ]
        }

        return result
    }

    private func extractPatreon(_ viewModel: PatreonViewModel, router: AppRouter) -> [String: Any] {
        var result: [String: Any] = [:]
        result["authState"] = viewModel.authState.displayName
        result["selectedPostID"] = router.selectedPostID ?? "none"
        result["selectedMemberID"] = router.selectedMemberID ?? "none"

        if let identity = viewModel.identity {
            result["identity"] = [
                "id": identity.data.id
            ]
        }

        if let campaign = viewModel.campaign {
            result["campaign"] = [
                "id": campaign.id
            ]
        }

        result["posts"] = viewModel.posts.prefix(5).map { post in
            [
                "id": post.id,
                "title": post.attributes.title,
                "isPaid": post.attributes.isPaid,
                "isPublic": post.attributes.isPublic
            ]
        }

        result["members"] = viewModel.members.prefix(5).map { member in
            [
                "id": member.id,
                "fullName": member.attributes?.fullName ?? "unknown"
            ]
        }

        result["tiers"] = viewModel.tiers.prefix(5).map { tier in
            [
                "id": tier.id,
                "title": tier.attributes.title,
                "amountCents": tier.attributes.amountCents ?? 0
            ]
        }

        return result
    }

    private func extractTools() -> [String: Any] {
        // TODO: Implement when Tools feature is explored
        return ["available": []]
    }

    private func extractSettings(_ viewModel: SettingsViewModel) -> [String: Any] {
        return [
            "taskScriptPath": viewModel.taskScriptPath
        ]
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
        }

        return jsonString
    }
}

// MARK: - Date Formatting Helper

private extension Date {
    func ISO8601Format() -> String {
        ISO8601DateFormatter().string(from: self)
    }
}
