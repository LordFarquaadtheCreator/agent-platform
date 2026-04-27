import Foundation

/// Agent protocol for defining agent behavior
public protocol AKAgent: Sendable {
    var id: UUID { get }
    var name: String { get }
    var tools: [any AgentTool] { get }

    func execute(task: AgentTask) async throws -> AgentTaskResult
}

/// Task to be executed by an agent
public struct AgentTask: Sendable {
    public let id: UUID
    public let instruction: String
    public let context: [String: String]

    public init(id: UUID = UUID(), instruction: String, context: [String: String] = [:]) {
        self.id = id
        self.instruction = instruction
        self.context = context
    }
}

/// Result of agent task execution
public struct AgentTaskResult: Sendable {
    public let success: Bool
    public let output: String
    public let metadata: [String: String]

    public init(success: Bool, output: String, metadata: [String: String] = [:]) {
        self.success = success
        self.output = output
        self.metadata = metadata
    }
}
