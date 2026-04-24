import Foundation

// MARK: - Resource Limits

public struct ToolLimits: Sendable {
    public let maxFileReadSize: Int
    public let maxWriteSize: Int
    public let maxDirectoryDepth: Int
    public let maxSearchResults: Int
    public let maxCommandOutput: Int
    public let defaultCommandTimeout: Int
    public let maxCommandTimeout: Int

    public init(
        maxFileReadSize: Int = 100 * 1024 * 1024,      // 100MB
        maxWriteSize: Int = 100 * 1024 * 1024,         // 100MB
        maxDirectoryDepth: Int = 10,
        maxSearchResults: Int = 1000,
        maxCommandOutput: Int = 10 * 1024 * 1024,       // 10MB
        defaultCommandTimeout: Int = 30,
        maxCommandTimeout: Int = 300                   // 5 min max
    ) {
        self.maxFileReadSize = maxFileReadSize
        self.maxWriteSize = maxWriteSize
        self.maxDirectoryDepth = maxDirectoryDepth
        self.maxSearchResults = maxSearchResults
        self.maxCommandOutput = maxCommandOutput
        self.defaultCommandTimeout = defaultCommandTimeout
        self.maxCommandTimeout = maxCommandTimeout
    }

    public static let `default` = ToolLimits()
}

// MARK: - Path Validation

public enum PathAccessLevel: Sendable {
    case readOnly       // Allowed for read operations
    case readWrite      // Allowed for read/write (only in sandbox)
    case prohibited     // Never allowed (.ssh, .env, etc.)
}

public enum PathValidationResult: Sendable {
    case allowed(URL, access: PathAccessLevel)
    case rejected(String)
}

public struct PathValidator: Sendable {
    private let sandboxRoot: URL
    private let homeDirectory: URL
    private let limits: ToolLimits

    // Patterns that are prohibited regardless of location
    private let prohibitedPatterns: [String] = [
        ".ssh",
        ".aws",
        ".env",
        ".netrc",
        ".docker",
        ".kube",
        ".npmrc",
        ".pypirc",
        "id_rsa",
        "id_ed25519",
        "id_dsa",
        ".git/hooks",      // Git hook injection risk
        "node_modules/.bin", // Executable injection
        ".cargo/bin",
    ]

    // System paths that are read-only (if accessible)
    private let readOnlySystemPaths: [String] = [
        "/System",
        "/bin",
        "/sbin",
        "/usr",
        "/lib",
        "/lib64",
        "/opt",
        "/dev",
        "/private",
    ]

    public init(sandboxRoot: URL, limits: ToolLimits = .default) {
        self.sandboxRoot = sandboxRoot.standardizedFileURL.resolvingSymlinksInPath()
        self.homeDirectory = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.resolvingSymlinksInPath()
        self.limits = limits
    }

    /// Validate a path for the requested access level
    public func validate(_ path: String, for access: PathAccessLevel) -> PathValidationResult {
        // Resolve the path
        let resolvedURL: URL
        if path.hasPrefix("/") {
            resolvedURL = URL(fileURLWithPath: path)
        } else {
            resolvedURL = sandboxRoot.appendingPathComponent(path)
        }

        // Normalize path (filesystem-safe, non-blocking)
        let normalized = resolvedURL.standardizedFileURL
        
        // Resolve symlinks only if file exists to avoid hanging on invalid paths
        let resolved: URL
        let fm = FileManager.default
        if fm.fileExists(atPath: normalized.path) {
            // Use realpath for existing files (handles symlinks)
            resolved = normalized.resolvingSymlinksInPath()
        } else {
            // For non-existent paths, just use normalized path
            // Path traversal validation will catch escapes
            resolved = normalized
        }

        let resolvedPath = resolved.path

        // Check prohibited patterns
        for pattern in prohibitedPatterns {
            if resolvedPath.contains(pattern) {
                return .rejected("Access to '\(pattern)' paths is prohibited for security")
            }
        }

        // Check if within sandbox
        let isInSandbox = resolvedPath.hasPrefix(sandboxRoot.path + "/") || resolvedPath == sandboxRoot.path

        // For write operations, must be in sandbox
        if access == .readWrite && !isInSandbox {
            return .rejected("Write operations only permitted within working directory: \(sandboxRoot.path)")
        }

        // Check system paths (read-only outside sandbox)
        if !isInSandbox {
            for systemPath in readOnlySystemPaths {
                if resolvedPath.hasPrefix(systemPath) {
                    if access == .readWrite {
                        return .rejected("System paths are read-only: \(resolvedPath)")
                    }
                    return .allowed(resolved, access: .readOnly)
                }
            }
        }

        // Check traversal depth
        let components = resolvedPath.replacingOccurrences(of: sandboxRoot.path, with: "")
            .split(separator: "/")
            .filter { !$0.isEmpty }
        if components.count > limits.maxDirectoryDepth {
            return .rejected("Path exceeds maximum directory depth (\(limits.maxDirectoryDepth))")
        }

        let accessLevel = isInSandbox ? PathAccessLevel.readWrite : PathAccessLevel.readOnly
        return .allowed(resolved, access: accessLevel)
    }

    /// Check if path contains symlinks that escape sandbox
    public func checkSymlinkEscape(_ path: String) -> PathValidationResult {
        var currentURL = path.hasPrefix("/") ? URL(fileURLWithPath: path) : sandboxRoot.appendingPathComponent(path)
        var visited: Set<String> = []

        while true {
            let pathStr = currentURL.path
            guard !visited.contains(pathStr) else {
                return .rejected("Symlink cycle detected")
            }
            visited.insert(pathStr)

            // Check if this specific path is a symlink
            do {
                let resourceValues = try currentURL.resourceValues(forKeys: [.isSymbolicLinkKey])
                if resourceValues.isSymbolicLink == true {
                    // Resolve the symlink target
                    let target = try FileManager.default.destinationOfSymbolicLink(atPath: pathStr)
                    let targetURL: URL
                    if target.hasPrefix("/") {
                        targetURL = URL(fileURLWithPath: target)
                    } else {
                        // Relative symlink - resolve from parent directory
                        targetURL = currentURL.deletingLastPathComponent().appendingPathComponent(target)
                    }

                    let resolvedTarget = targetURL.standardizedFileURL.resolvingSymlinksInPath()
                    let isInSandbox = resolvedTarget.path.hasPrefix(sandboxRoot.path + "/") ||
                                     resolvedTarget.path == sandboxRoot.path

                    if !isInSandbox {
                        return .rejected("Symlink escapes working directory sandbox: \(pathStr) → \(resolvedTarget.path)")
                    }
                    currentURL = resolvedTarget
                    continue
                }
            } catch {
                // Not a symlink or error checking - continue to parent
            }

            // Move to parent directory
            let parent = currentURL.deletingLastPathComponent()
            if parent.path == currentURL.path || parent.path == "/" {
                break
            }
            currentURL = parent
        }

        return .allowed(URL(fileURLWithPath: path), access: .readWrite)
    }
}

// MARK: - Command Validation

public struct CommandValidator: Sendable {
    // Safe commands that can be executed directly (no shell)
    private let safeCommands: Set<String> = [
        "ls", "cat", "head", "tail", "find", "grep", "wc", "pwd",
        "echo", "printf", "sort", "uniq", "diff", "file",
        "git",                                    // Git allowed but hooks protected
        "swift", "xcodebuild",                  // Swift development
        "mkdir", "rmdir", "touch",              // File ops (but sandboxed anyway)
    ]

    // Network commands that are blocked
    private let networkCommands: Set<String> = [
        "curl", "wget", "nc", "netcat", "telnet", "ftp", "sftp",
        "ssh", "scp", "rsync", "ping", "traceroute",
    ]

    // Shell metacharacters that enable command injection
    private let dangerousChars: Set<Character> = [
        ";", "&", "|", "`", "$", "(", ")", "<", ">", "{", "}",
    ]

    public init() {}

    /// Validate a shell command for safe execution
    public func validate(_ command: String, allowUnsafe: Bool = false) -> Result<(executable: String, args: [String]), CommandValidationError> {
        let trimmed = command.trimmingCharacters(in: .whitespaces)

        // Check for dangerous characters
        for char in trimmed {
            if dangerousChars.contains(char) {
                return .failure(CommandValidationError("Command contains unsafe character: '\(char)'. Shell metacharacters are not allowed."))
            }
        }

        // Parse command (simple space separation)
        let parts = trimmed.split(separator: " ", omittingEmptySubsequences: true)
        guard let first = parts.first else {
            return .failure(CommandValidationError("Empty command"))
        }

        let executable = String(first)

        // Check for network commands
        if networkCommands.contains(executable) {
            return .failure(CommandValidationError("Network command '\(executable)' is not allowed for security"))
        }

        // If not in safe list and not allowing unsafe, reject
        if !safeCommands.contains(executable) && !allowUnsafe {
            return .failure(CommandValidationError("Command '\(executable)' is not in the allowed list. Enable unsafe mode to allow arbitrary commands."))
        }

        let args = parts.dropFirst().map { String($0) }
        return .success((executable: executable, args: args))
    }

    public struct CommandValidationError: Error, LocalizedError {
        public let message: String
        public init(_ message: String) { self.message = message }
        public var errorDescription: String? { message }
    }

    /// Check if command should use shell (unsafe mode) or direct execution
    public func shouldUseShell(_ command: String) -> Bool {
        for char in command {
            if dangerousChars.contains(char) {
                return true
            }
        }
        return false
    }
}

// MARK: - ToolExecutionContext Extensions

extension ToolExecutionContext {
    /// Validate a path for read access (allows outside sandbox)
    public func validatePathForRead(_ path: String) throws -> URL {
        let validator = PathValidator(sandboxRoot: workingDirectory)

        // First check for symlink escapes
        let symlinkCheck = validator.checkSymlinkEscape(path)
        if case .rejected(let reason) = symlinkCheck {
            throw ToolError.sandboxViolation(reason)
        }

        // Then validate access
        let result = validator.validate(path, for: .readOnly)
        switch result {
        case .allowed(let url, _):
            return url
        case .rejected(let reason):
            throw ToolError.sandboxViolation(reason)
        }
    }

    /// Validate a path for write access (sandbox only)
    public func validatePathForWrite(_ path: String) throws -> URL {
        let validator = PathValidator(sandboxRoot: workingDirectory)

        // First check for symlink escapes
        let symlinkCheck = validator.checkSymlinkEscape(path)
        if case .rejected(let reason) = symlinkCheck {
            throw ToolError.sandboxViolation(reason)
        }

        // Then validate access
        let result = validator.validate(path, for: .readWrite)
        switch result {
        case .allowed(let url, _):
            return url
        case .rejected(let reason):
            throw ToolError.sandboxViolation(reason)
        }
    }

    /// Check file size against limits before reading
    public func checkReadSize(_ size: Int) throws {
        // Would need to get limits from context - for now use default
        let limits = ToolLimits.default
        if size > limits.maxFileReadSize {
            throw ToolError.resourceLimit("File size \(size) exceeds maximum allowed (\(limits.maxFileReadSize))")
        }
    }

    /// Check write size against limits
    public func checkWriteSize(_ size: Int) throws {
        let limits = ToolLimits.default
        if size > limits.maxWriteSize {
            throw ToolError.resourceLimit("Write size \(size) exceeds maximum allowed (\(limits.maxWriteSize))")
        }
    }
}

// MARK: - ToolError Extensions

extension ToolError {
    static func sandboxViolation(_ message: String) -> ToolError {
        .executionFailed("Sandbox violation: \(message)")
    }

    static func resourceLimit(_ message: String) -> ToolError {
        .executionFailed("Resource limit exceeded: \(message)")
    }
}
