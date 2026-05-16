import Foundation

// MARK: - Workflow

public struct ComfyUIWorkflow: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let path: String
    public let nodes: [ComfyUINode]

    public init(id: String, name: String, path: String, nodes: [ComfyUINode]) {
        self.id = id
        self.name = name
        self.path = path
        self.nodes = nodes
    }
}

// MARK: - Node

public struct ComfyUINode: Identifiable, Hashable, Sendable {
    public let id: String
    public let classType: String
    public let inputs: [ComfyUIInputParameter]
    public let isSubgraph: Bool

    public init(id: String, classType: String, inputs: [ComfyUIInputParameter], isSubgraph: Bool = false) {
        self.id = id
        self.classType = classType
        self.inputs = inputs
        self.isSubgraph = isSubgraph
    }
}

// MARK: - Input Parameter

public struct ComfyUIInputParameter: Identifiable, Hashable, Sendable {
    public let id: String
    public let key: String
    public let type: ComfyUIInputType
    public let defaultValue: String
    public let currentValue: String
    public let options: [String]?
    public let minValue: Double?
    public let maxValue: Double?
    public let step: Double?

    public init(
        id: String,
        key: String,
        type: ComfyUIInputType,
        defaultValue: String = "",
        currentValue: String = "",
        options: [String]? = nil,
        minValue: Double? = nil,
        maxValue: Double? = nil,
        step: Double? = nil
    ) {
        self.id = id
        self.key = key
        self.type = type
        self.defaultValue = defaultValue
        self.currentValue = currentValue
        self.options = options
        self.minValue = minValue
        self.maxValue = maxValue
        self.step = step
    }
}

public enum ComfyUIInputType: String, Codable, Sendable {
    case string
    case int
    case float
    case boolean
    case combo
    case image
}

// MARK: - Execution

public enum ComfyUIExecutionStatus: String, Codable, Sendable {
    case queued
    case running
    case completed
    case error
    case cancelled
}

public struct ComfyUIExecution: Identifiable, Hashable, Sendable {
    public let id: String
    public let workflowID: String
    public let workflowName: String
    public let status: ComfyUIExecutionStatus
    public let progress: Double
    public let currentNode: String?
    public let startedAt: Date?
    public let completedAt: Date?
    public let outputs: [String]
    public let outputDirectory: String
    public let errorMessage: String?

    public init(
        id: String,
        workflowID: String,
        workflowName: String,
        status: ComfyUIExecutionStatus = .queued,
        progress: Double = 0,
        currentNode: String? = nil,
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        outputs: [String] = [],
        outputDirectory: String = "",
        errorMessage: String? = nil
    ) {
        self.id = id
        self.workflowID = workflowID
        self.workflowName = workflowName
        self.status = status
        self.progress = progress
        self.currentNode = currentNode
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.outputs = outputs
        self.outputDirectory = outputDirectory
        self.errorMessage = errorMessage
    }
}

// MARK: - Queue Status

public struct ComfyUIQueueStatus: Sendable {
    public let runningItem: ComfyUIQueueItem?
    public let pendingItems: [ComfyUIQueueItem]

    public init(runningItem: ComfyUIQueueItem? = nil, pendingItems: [ComfyUIQueueItem] = []) {
        self.runningItem = runningItem
        self.pendingItems = pendingItems
    }
}

public struct ComfyUIQueueItem: Identifiable, Sendable {
    public let id: String
    public let promptID: String
    public let number: Int

    public init(id: String, promptID: String, number: Int) {
        self.id = id
        self.promptID = promptID
        self.number = number
    }
}
