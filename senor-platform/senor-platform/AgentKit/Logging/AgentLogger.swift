import Foundation
import OSLog

/// Basically a wrapper for native logger for agents to use

/// Logging protocol for AgentKit
public protocol AgentLogger: Sendable {
    func debug(_ message: String)
    func info(_ message: String)
    func warning(_ message: String)
    func error(_ message: String)
}

/// OSLog-based logger -> fully public logging
public struct DefaultAgentLogger: AgentLogger {
    private let logger: Logger

    public init(subsystem: String, category: String) {
        self.logger = Logger(subsystem: subsystem, category: category)
    }

    public func debug(_ message: String) {
        logger.debug("\(message)")
    }

    public func info(_ message: String) {
        logger.info("\(message)")
    }

    public func warning(_ message: String) {
        logger.warning("\(message)")
    }

    public func error(_ message: String) {
        logger.error("\(message)")
    }
}

public extension DefaultAgentLogger {
    static let `default` = DefaultAgentLogger(subsystem: "com.agentkit", category: "General")
}
