import Foundation

/// Global error taxonomy for SenorPlatform
public enum AppError: Error, Sendable {
    // Database errors
    case databaseConnectionFailed(Error)
    case databaseMigrationFailed(String)
    case databaseQueryFailed(String)
    case databaseConstraintViolation(String)

    // Validation errors
    case invalidJSON(String)
    case schemaValidationFailed(String, [ValidationError])
    case invalidTaskConfiguration(String)
    case invalidScheduleConfiguration(String)

    // Runtime errors
    case workerProcessFailed(Int32, String)
    case workerSpawnFailed(Error)
    case workerTerminationFailed(Error)
    case taskExecutionFailed(String)

    // API/Integration errors
    case apiRequestFailed(String, Error)
    case apiAuthenticationFailed(String)
    case apiRateLimited(Int)
    case apiResourceNotFound(String)
    case decodingFailed(String)

    // Cache errors
    case cacheReadFailed(String)
    case cacheWriteFailed(String)

    // Content/Approval errors
    case contentVersioningFailed(String)
    case approvalStateInvalid(String)
    case publicationFailed(String)

    // Configuration errors
    case invalidConfiguration(String)
    case missingRequiredField(String)

    public struct ValidationError: Sendable {
        public let field: String
        public let message: String
        public let jsonPointer: String?

        public init(field: String, message: String, jsonPointer: String? = nil) {
            self.field = field
            self.message = message
            self.jsonPointer = jsonPointer
        }
    }

    public var localizedDescription: String {
        switch self {
        case .databaseConnectionFailed(let error):
            return "Database connection failed: \(error.localizedDescription)"

        case .databaseMigrationFailed(let message):
            return "Database migration failed: \(message)"

        case .databaseQueryFailed(let message):
            return "Database query failed: \(message)"

        case .databaseConstraintViolation(let message):
            return "Database constraint violation: \(message)"

        case .invalidJSON(let message):
            return "Invalid JSON: \(message)"

        case .schemaValidationFailed(let type, let errors):
            let errorMessages = errors.map { "\($0.field): \($0.message)" }.joined(separator: ", ")
            return "Schema validation failed for '\(type)': \(errorMessages)"

        case .invalidTaskConfiguration(let message):
            return "Invalid task configuration: \(message)"

        case .invalidScheduleConfiguration(let message):
            return "Invalid schedule configuration: \(message)"

        case .workerProcessFailed(let exitCode, let message):
            return "Worker process failed (exit code \(exitCode)): \(message)"

        case .workerSpawnFailed(let error):
            return "Failed to spawn worker: \(error.localizedDescription)"

        case .workerTerminationFailed(let error):
            return "Failed to terminate worker: \(error.localizedDescription)"

        case .taskExecutionFailed(let message):
            return "Task execution failed: \(message)"

        case .apiRequestFailed(let endpoint, let error):
            return "API request failed for '\(endpoint)': \(error.localizedDescription)"

        case .apiAuthenticationFailed(let platform):
            return "API authentication failed for '\(platform)'. Please re-authenticate."

        case .apiRateLimited(let retryAfter):
            return "API rate limited. Retry after \(retryAfter) seconds."

        case .apiResourceNotFound(let resource):
            return "API resource not found: \(resource)"

        case .decodingFailed(let message):
            return "Failed to decode response: \(message)"

        case .cacheReadFailed(let message):
            return "Cache read failed: \(message)"

        case .cacheWriteFailed(let message):
            return "Cache write failed: \(message)"

        case .contentVersioningFailed(let message):
            return "Content versioning failed: \(message)"

        case .approvalStateInvalid(let message):
            return "Invalid approval state: \(message)"

        case .publicationFailed(let message):
            return "Publication failed: \(message)"

        case .invalidConfiguration(let message):
            return "Invalid configuration: \(message)"

        case .missingRequiredField(let field):
            return "Missing required field: \(field)"
        }
    }

    /// User-facing error message for UI display
    public var userMessage: String {
        switch self {
        case .databaseConnectionFailed,
             .databaseMigrationFailed,
             .databaseQueryFailed:
            return "A database error occurred. Please restart the application."

        case .schemaValidationFailed:
            return "The task configuration is invalid. Please check your settings."

        case .workerProcessFailed:
            return "The worker process failed to complete the task."

        case .workerSpawnFailed:
            return "Failed to start the worker process."

        case .apiAuthenticationFailed:
            return "Authentication expired. Please reconnect your account."

        case .apiRateLimited:
            return "Too many requests. Please wait a moment."

        case .apiRequestFailed:
            return "Failed to connect to the service. Please try again."

        case .publicationFailed:
            return "Failed to publish content. Please check your settings and try again."

        default:
            return localizedDescription
        }
    }

    /// Whether this error is recoverable (can be retried)
    public var isRecoverable: Bool {
        switch self {
        case .apiRateLimited,
             .apiRequestFailed,
             .workerProcessFailed,
             .taskExecutionFailed:
            return true

        case .databaseConnectionFailed,
             .databaseMigrationFailed,
             .databaseConstraintViolation,
             .invalidJSON,
             .schemaValidationFailed,
             .invalidTaskConfiguration,
             .invalidScheduleConfiguration,
             .missingRequiredField:
            return false

        default:
            return false
        }
    }
}

/// Extension for converting errors to AppError
public extension Error {
    func asAppError() -> AppError {
        if let appError = self as? AppError {
            return appError
        }
        return AppError.invalidConfiguration(self.localizedDescription)
    }
}
