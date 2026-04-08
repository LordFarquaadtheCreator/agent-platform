import Foundation
import OSLog

/// Centralized logging for the application
public struct AppLogger: Sendable {
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

    public func fault(_ message: String) {
        logger.fault("\(message)")
    }

    /// Log an error with context, redacting sensitive fields
    public func logError(_ error: Error, context: String, sensitiveFields: [String] = []) {
        let safeContext = redactSensitiveInfo(context, fields: sensitiveFields)
        let errorDescription = redactSensitiveInfo(error.localizedDescription, fields: sensitiveFields)
        logger.error("[\(safeContext)] Error: \(errorDescription)")
    }

    private func redactSensitiveInfo(_ text: String, fields: [String]) -> String {
        var result = text
        for field in fields {
            // Simple redaction pattern - in production, use more sophisticated patterns
            result = result.replacingOccurrences(of: "\(field)=", with: "\(field)=<REDACTED>")
            result = result.replacingOccurrences(of: "\"\(field)\":", with: "\"\(field)\":\"<REDACTED>\"")
        }
        return result
    }
}

/// Predefined loggers for common modules
public extension AppLogger {
    nonisolated static let database = AppLogger(subsystem: "com.senorplatform", category: "Database")
    nonisolated static let worker = AppLogger(subsystem: "com.senorplatform", category: "Worker")
    nonisolated static let scheduler = AppLogger(subsystem: "com.senorplatform", category: "Scheduler")
    nonisolated static let api = AppLogger(subsystem: "com.senorplatform", category: "API")
    nonisolated static let ui = AppLogger(subsystem: "com.senorplatform", category: "UI")
    nonisolated static let agentNaming = AppLogger(subsystem: "com.senorplatform", category: "AgentNaming")
    nonisolated static let taskEngine = AppLogger(subsystem: "com.senorplatform", category: "TaskEngine")
    nonisolated static let general = AppLogger(subsystem: "com.senorplatform", category: "General")
}

