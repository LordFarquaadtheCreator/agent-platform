import Foundation
#if canImport(GRDB)
@preconcurrency import GRDB
#endif

// MARK: - Agent Record
/// Agent database record - conforms to Sendable because all properties are value types
public struct AgentRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    #if canImport(GRDB)
    public static let databaseTableName = "agents"
    #endif

    public var id: String
    public var displayName: String
    public var status: AgentRuntimeStatus
    public var nameSource: String
    public var nameSeed: Int
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String = UUID().uuidString,
        displayName: String,
        status: AgentRuntimeStatus = .idle,
        nameSource: String,
        nameSeed: Int,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.status = status
        self.nameSource = nameSource
        self.nameSeed = nameSeed
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// Agent runtime status
public enum AgentRuntimeStatus: String, Codable, CaseIterable, Sendable {
    case idle
    case running
    case paused
    case error

    public var displayName: String {
        rawValue.capitalized
    }
}

// MARK: - Task Type Record
/// Task type database record - conforms to Sendable because all properties are value types
public struct TaskTypeRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    #if canImport(GRDB)
    public static let databaseTableName = "task_types"
    #endif

    public var id: String
    public var name: String
    public var schemaVersion: Int
    public var jsonSchema: String
    public var description: String?
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        name: String,
        schemaVersion: Int,
        jsonSchema: String,
        description: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.schemaVersion = schemaVersion
        self.jsonSchema = jsonSchema
        self.description = description
        self.createdAt = createdAt
    }
}

// MARK: - Task Record
/// Task database record - conforms to Sendable because all properties are value types
public struct TaskRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    #if canImport(GRDB)
    public static let databaseTableName = "tasks"
    #endif

    public var id: String
    public var agentId: String
    public var taskTypeId: String
    public var taskName: String
    public var taskMetadataJson: String
    public var goScriptPath: String
    public var isEnabled: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String = UUID().uuidString,
        agentId: String,
        taskTypeId: String,
        taskName: String,
        taskMetadataJson: String,
        goScriptPath: String,
        isEnabled: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.agentId = agentId
        self.taskTypeId = taskTypeId
        self.taskName = taskName
        self.taskMetadataJson = taskMetadataJson
        self.goScriptPath = goScriptPath
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Task Schedule Record
/// Task schedule database record - conforms to Sendable because all properties are value types
public struct TaskScheduleRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    #if canImport(GRDB)
    public static let databaseTableName = "task_schedules"
    #endif

    public var id: String
    public var taskId: String
    public var scheduleKind: String
    public var schedulePayloadJson: String
    public var cronExpression: String
    public var timezone: String
    public var nextRunAt: Date?
    public var isActive: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String = UUID().uuidString,
        taskId: String,
        scheduleKind: String,
        schedulePayloadJson: String,
        cronExpression: String,
        timezone: String,
        nextRunAt: Date? = nil,
        isActive: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.taskId = taskId
        self.scheduleKind = scheduleKind
        self.schedulePayloadJson = schedulePayloadJson
        self.cronExpression = cronExpression
        self.timezone = timezone
        self.nextRunAt = nextRunAt
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Task Run Record
/// Task run database record - conforms to Sendable because all properties are value types
public struct TaskRunRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    #if canImport(GRDB)
    public static let databaseTableName = "task_runs"
    #endif

    public var id: String
    public var taskId: String
    public var agentId: String
    public var workerPid: Int?
    public var triggerSource: String
    public var scheduledFor: Date
    public var startedAt: Date?
    public var completedAt: Date?
    public var status: String
    public var exitCode: Int?
    public var stdoutLogPath: String?
    public var stderrLogPath: String?
    public var errorMessage: String?

    public init(
        id: String = UUID().uuidString,
        taskId: String,
        agentId: String,
        workerPid: Int? = nil,
        triggerSource: String,
        scheduledFor: Date,
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        status: String = "scheduled",
        exitCode: Int? = nil,
        stdoutLogPath: String? = nil,
        stderrLogPath: String? = nil,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.taskId = taskId
        self.agentId = agentId
        self.workerPid = workerPid
        self.triggerSource = triggerSource
        self.scheduledFor = scheduledFor
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.status = status
        self.exitCode = exitCode
        self.stdoutLogPath = stdoutLogPath
        self.stderrLogPath = stderrLogPath
        self.errorMessage = errorMessage
    }
}

// MARK: - Generated Content Record
/// Generated content database record - conforms to Sendable because all properties are value types
public struct GeneratedContentRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    #if canImport(GRDB)
    public static let databaseTableName = "generated_content"
    #endif

    public var id: String
    public var taskRunId: String
    public var agentId: String
    public var title: String
    public var generatedContentJson: String
    public var currentVersion: Int
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String = UUID().uuidString,
        taskRunId: String,
        agentId: String,
        title: String,
        generatedContentJson: String,
        currentVersion: Int = 1,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.taskRunId = taskRunId
        self.agentId = agentId
        self.title = title
        self.generatedContentJson = generatedContentJson
        self.currentVersion = currentVersion
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Generated Content Version Record
/// Content version database record - conforms to Sendable because all properties are value types
public struct GeneratedContentVersionRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    #if canImport(GRDB)
    public static let databaseTableName = "generated_content_versions"
    #endif

    public var id: String
    public var generatedContentId: String
    public var version: Int
    public var contentSnapshotJson: String
    public var changeReason: String?
    public var editedBy: String?
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        generatedContentId: String,
        version: Int,
        contentSnapshotJson: String,
        changeReason: String? = nil,
        editedBy: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.generatedContentId = generatedContentId
        self.version = version
        self.contentSnapshotJson = contentSnapshotJson
        self.changeReason = changeReason
        self.editedBy = editedBy
        self.createdAt = createdAt
    }
}

// MARK: - Approval Queue Record
/// Approval queue database record - conforms to Sendable because all properties are value types
public struct ApprovalQueueRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    #if canImport(GRDB)
    public static let databaseTableName = "approval_queue"
    #endif

    public var id: String
    public var generatedContentId: String
    public var approvalStatus: String
    public var approvedBy: String?
    public var approvedAt: Date?
    public var rejectedAt: Date?
    public var rejectionReason: String?
    public var batchToken: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String = UUID().uuidString,
        generatedContentId: String,
        approvalStatus: String = "pending",
        approvedBy: String? = nil,
        approvedAt: Date? = nil,
        rejectedAt: Date? = nil,
        rejectionReason: String? = nil,
        batchToken: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.generatedContentId = generatedContentId
        self.approvalStatus = approvalStatus
        self.approvedBy = approvedBy
        self.approvedAt = approvedAt
        self.rejectedAt = rejectedAt
        self.rejectionReason = rejectionReason
        self.batchToken = batchToken
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Publication Target Record
/// Publication target database record - conforms to Sendable because all properties are value types
public struct PublicationTargetRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    #if canImport(GRDB)
    public static let databaseTableName = "publication_targets"
    #endif

    public var id: String
    public var generatedContentId: String
    public var platform: String
    public var remotePostId: String?
    public var remoteUrl: String?
    public var state: PublicationState
    public var scheduledAt: Date?
    public var publishedAt: Date?
    public var errorMessage: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String = UUID().uuidString,
        generatedContentId: String,
        platform: String,
        remotePostId: String? = nil,
        remoteUrl: String? = nil,
        state: PublicationState = .pending,
        scheduledAt: Date? = nil,
        publishedAt: Date? = nil,
        errorMessage: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.generatedContentId = generatedContentId
        self.platform = platform
        self.remotePostId = remotePostId
        self.remoteUrl = remoteUrl
        self.state = state
        self.scheduledAt = scheduledAt
        self.publishedAt = publishedAt
        self.errorMessage = errorMessage
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case generatedContentId = "generated_content_id"
        case platform
        case state
        case scheduledAt = "scheduled_at"
        case remotePostId = "remote_post_id"
        case remoteUrl = "remote_url"
        case errorMessage = "error_message"
        case publishedAt = "published_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Remote Post Cache Record
/// Remote post cache database record - conforms to Sendable because all properties are value types
public struct RemotePostCacheRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    #if canImport(GRDB)
    public static let databaseTableName = "remote_post_cache"
    #endif

    public var id: String
    public var platform: String
    public var cacheKey: String
    public var payloadJson: String
    public var statsJson: String?
    public var fetchedAt: Date
    public var expiresAt: Date

    public init(
        id: String = UUID().uuidString,
        platform: String,
        cacheKey: String,
        payloadJson: String,
        statsJson: String? = nil,
        fetchedAt: Date = Date(),
        expiresAt: Date
    ) {
        self.id = id
        self.platform = platform
        self.cacheKey = cacheKey
        self.payloadJson = payloadJson
        self.statsJson = statsJson
        self.fetchedAt = fetchedAt
        self.expiresAt = expiresAt
    }
}

// MARK: - Patreon Stats Record
/// Historical Patreon statistics for tracking trends over time
public struct PatreonStatsRecord: Codable, FetchableRecord, PersistableRecord, Sendable, Identifiable {
    #if canImport(GRDB)
    public static let databaseTableName = "patreon_stats"
    #endif

    public var id: String
    public var timestamp: Date
    public var totalPatrons: Int
    public var activePatrons: Int
    public var totalRevenueCents: Int
    public var monthlyRevenueCents: Int

    public init(
        id: String = UUID().uuidString,
        timestamp: Date,
        totalPatrons: Int,
        activePatrons: Int,
        totalRevenueCents: Int,
        monthlyRevenueCents: Int
    ) {
        self.id = id
        self.timestamp = timestamp
        self.totalPatrons = totalPatrons
        self.activePatrons = activePatrons
        self.totalRevenueCents = totalRevenueCents
        self.monthlyRevenueCents = monthlyRevenueCents
    }

    enum CodingKeys: String, CodingKey {
        case id
        case timestamp
        case totalPatrons = "total_patrons"
        case activePatrons = "active_patrons"
        case totalRevenueCents = "total_revenue_cents"
        case monthlyRevenueCents = "monthly_revenue_cents"
    }
}

// MARK: - Patreon Pledge Event Record
/// Pledge event from Patreon API for notification timeline
public struct PatreonPledgeEventRecord: Codable, FetchableRecord, PersistableRecord, Sendable, Identifiable {
    #if canImport(GRDB)
    public static let databaseTableName = "patreon_pledge_events"
    #endif

    public var id: String
    public var memberId: String
    public var eventType: String
    public var date: Date
    public var amountCents: Int?
    public var paymentStatus: String?
    public var tierId: String?
    public var tierTitle: String?

    public init(
        id: String = UUID().uuidString,
        memberId: String,
        eventType: String,
        date: Date,
        amountCents: Int? = nil,
        paymentStatus: String? = nil,
        tierId: String? = nil,
        tierTitle: String? = nil
    ) {
        self.id = id
        self.memberId = memberId
        self.eventType = eventType
        self.date = date
        self.amountCents = amountCents
        self.paymentStatus = paymentStatus
        self.tierId = tierId
        self.tierTitle = tierTitle
    }

    enum CodingKeys: String, CodingKey {
        case id
        case memberId = "member_id"
        case eventType = "event_type"
        case date
        case amountCents = "amount_cents"
        case paymentStatus = "payment_status"
        case tierId = "tier_id"
        case tierTitle = "tier_title"
    }
}

// MARK: - ComfyUI Execution Record

public struct ComfyUIExecutionRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    #if canImport(GRDB)
    public static let databaseTableName = "comfyui_executions"
    #endif

    public var id: String
    public var workflowID: String
    public var workflowName: String
    public var inputsJson: String
    public var status: String
    public var progress: Double
    public var currentNode: String?
    public var startedAt: Date?
    public var completedAt: Date?
    public var outputPathsJson: String
    public var outputDirectory: String
    public var errorMessage: String?
    public var createdAt: Date

    public init(
        id: String,
        workflowID: String,
        workflowName: String,
        inputsJson: String,
        status: String,
        progress: Double = 0,
        currentNode: String? = nil,
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        outputPathsJson: String = "[]",
        outputDirectory: String = "",
        errorMessage: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.workflowID = workflowID
        self.workflowName = workflowName
        self.inputsJson = inputsJson
        self.status = status
        self.progress = progress
        self.currentNode = currentNode
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.outputPathsJson = outputPathsJson
        self.outputDirectory = outputDirectory
        self.errorMessage = errorMessage
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case workflowID = "workflow_id"
        case workflowName = "workflow_name"
        case inputsJson = "inputs_json"
        case status
        case progress
        case currentNode = "current_node"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case outputPathsJson = "output_paths_json"
        case outputDirectory = "output_directory"
        case errorMessage = "error_message"
        case createdAt = "created_at"
    }
}
