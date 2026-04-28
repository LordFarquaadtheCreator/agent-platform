import Foundation

// MARK: - Constants

private enum Encoding: String {
    case utf8
    case base64
}

private enum FileMode: String {
    case overwrite
    case append
}

// MARK: - Helpers

private func encodeJSON<T: Encodable>(_ value: T) throws -> String {
    let data = try JSONEncoder().encode(value)
    guard let json = String(data: data, encoding: .utf8) else {
        throw ToolError.invalidInput("Failed to encode JSON")
    }
    return json
}

private func fileAttributeTypeString(from attributes: [FileAttributeKey: Any]) -> String? {
    if let type = attributes[.type] as? FileAttributeType {
        return type.rawValue
    }
    return attributes[.type] as? String
}

// MARK: - File Operations

public struct ReadFileTool: AgentTool {
    public init() {}

    nonisolated public static let toolName = "read_file"
    nonisolated public static let toolDescription = "Read the contents of a file as text or base64"

    nonisolated public static var inputSchema: ToolInputSchema {
        ToolInputSchema(
            properties: [
                "path": PropertySchema(type: "string", description: "Absolute path to the file"),
                "encoding": PropertySchema(type: "string", description: "Encoding: 'utf8' or 'base64'",
                                            defaultValue: "utf8")
            ],
            required: ["path"]
        )
    }

    nonisolated public static var outputSchema: ToolOutputSchema {
        ToolOutputSchema(
            properties: [
                "content": PropertySchema(type: "string", description: "File content"),
                "encoding": PropertySchema(type: "string", description: "Encoding used")
            ],
            description: "File contents"
        )
    }

    public func execute(input: String, context: ToolExecutionContext) async throws -> String {
        let params = try JSONDecoder().decode(Input.self, from: Data(input.utf8))
        let url = try context.validatePathForRead(params.path)

        // Use injected file manager for all operations
        let fm = await context.serviceProvider.getFileManager()

        // Check file size before reading
        if let attrs = try? await fm.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int {
            try context.checkReadSize(size)
        }

        let data = try await fm.read(from: url)
        let encoding = params.encoding ?? "utf8"

        let content: String
        if encoding == "base64" {
            content = data.base64EncodedString()
        } else {
            guard let utf8Content = String(data: data, encoding: .utf8) else {
                throw ToolError.invalidInput("File contains non-UTF8 binary data. Use 'base64' encoding.")
            }
            content = utf8Content
        }

        let output = Output(content: content, encoding: encoding)
        return try encodeJSON(output)
    }

    struct Input: Codable {
        let path: String
        let encoding: String?
    }

    struct Output: Codable {
        let content: String
        let encoding: String
    }
}

public struct CreateFileTool: AgentTool {
    public init() {}

    nonisolated public static let toolName = "create_file"
    nonisolated public static let toolDescription = "Create a new file with the given content"

    nonisolated public static var inputSchema: ToolInputSchema {
        ToolInputSchema(
            properties: [
                "path": PropertySchema(type: "string", description: "Absolute path for the new file"),
                "content": PropertySchema(type: "string", description: "File content"),
                "encoding": PropertySchema(type: "string", description: "Encoding: 'utf8' or 'base64'",
                                            defaultValue: "utf8")
            ],
            required: ["path", "content"]
        )
    }

    nonisolated public static var outputSchema: ToolOutputSchema {
        ToolOutputSchema(
            properties: [
                "success": PropertySchema(type: "boolean"),
                "path": PropertySchema(type: "string")
            ]
        )
    }

    public func execute(input: String, context: ToolExecutionContext) async throws -> String {
        let params = try JSONDecoder().decode(Input.self, from: Data(input.utf8))
        let url = try context.validatePathForWrite(params.path)

        let data: Data
        if params.encoding == "base64" {
            guard let decoded = Data(base64Encoded: params.content) else {
                throw ToolError.invalidInput("Invalid base64 content")
            }
            data = decoded
        } else {
            data = Data(params.content.utf8)
        }

        try context.checkWriteSize(data.count)
        let fm = await context.serviceProvider.getFileManager()
        try await fm.write(data: data, to: url)

        let output = Output(success: true, path: params.path)
        return try encodeJSON(output)
    }

    struct Input: Codable {
        let path: String
        let content: String
        let encoding: String?
    }

    struct Output: Codable {
        let success: Bool
        let path: String
    }
}

public struct WriteFileTool: AgentTool {
    public init() {}

    nonisolated public static let toolName = "write_file"
    nonisolated public static let toolDescription = "Write or append content to a file"

    nonisolated public static var inputSchema: ToolInputSchema {
        ToolInputSchema(
            properties: [
                "path": PropertySchema(type: "string", description: "Absolute path to the file"),
                "content": PropertySchema(type: "string", description: "Content to write"),
                "mode": PropertySchema(type: "string", description: "'overwrite' or 'append'",
                                        defaultValue: "overwrite"),
                "encoding": PropertySchema(type: "string", description: "Encoding: 'utf8' or 'base64'",
                                            defaultValue: "utf8")
            ],
            required: ["path", "content"]
        )
    }

    nonisolated public static var outputSchema: ToolOutputSchema {
        ToolOutputSchema(
            properties: [
                "success": PropertySchema(type: "boolean"),
                "bytesWritten": PropertySchema(type: "integer")
            ]
        )
    }

    public func execute(input: String, context: ToolExecutionContext) async throws -> String {
        let params = try JSONDecoder().decode(Input.self, from: Data(input.utf8))
        let url = try context.validatePathForWrite(params.path)
        let fm = await context.serviceProvider.getFileManager()

        let newData: Data
        if params.encoding == "base64" {
            guard let decoded = Data(base64Encoded: params.content) else {
                throw ToolError.invalidInput("Invalid base64 content")
            }
            newData = decoded
        } else {
            newData = Data(params.content.utf8)
        }

        try context.checkWriteSize(newData.count)

        let dataToWrite: Data
        if params.mode == "append", await fm.exists(at: url) {
            let existing = try await fm.read(from: url)
            dataToWrite = existing + newData
        } else {
            dataToWrite = newData
        }

        try await fm.write(data: dataToWrite, to: url)

        let output = Output(success: true, bytesWritten: newData.count)
        return try encodeJSON(output)
    }

    struct Input: Codable {
        let path: String
        let content: String
        let mode: String?
        let encoding: String?
    }

    struct Output: Codable {
        let success: Bool
        let bytesWritten: Int
    }
}

public struct DeleteFileTool: AgentTool {
    public init() {}

    nonisolated public static let toolName = "delete_file"
    nonisolated public static let toolDescription = "Delete a file"

    nonisolated public static var inputSchema: ToolInputSchema {
        ToolInputSchema(
            properties: [
                "path": PropertySchema(type: "string", description: "Absolute path to the file")
            ],
            required: ["path"]
        )
    }

    nonisolated public static var outputSchema: ToolOutputSchema {
        ToolOutputSchema(
            properties: [
                "success": PropertySchema(type: "boolean"),
                "path": PropertySchema(type: "string")
            ]
        )
    }

    public func execute(input: String, context: ToolExecutionContext) async throws -> String {
        let params = try JSONDecoder().decode(Input.self, from: Data(input.utf8))
        let url = try context.validatePathForWrite(params.path)

        let fm = await context.serviceProvider.getFileManager()
        try await fm.delete(at: url)

        let output = Output(success: true, path: params.path)
        return try encodeJSON(output)
    }

    struct Input: Codable {
        let path: String
    }

    struct Output: Codable {
        let success: Bool
        let path: String
    }
}

public struct MoveFileTool: AgentTool {
    public init() {}

    nonisolated public static let toolName = "move_file"
    nonisolated public static let toolDescription = "Move or rename a file"

    nonisolated public static var inputSchema: ToolInputSchema {
        ToolInputSchema(
            properties: [
                "source": PropertySchema(type: "string", description: "Source file path"),
                "destination": PropertySchema(type: "string", description: "Destination file path")
            ],
            required: ["source", "destination"]
        )
    }

    nonisolated public static var outputSchema: ToolOutputSchema {
        ToolOutputSchema(
            properties: [
                "success": PropertySchema(type: "boolean"),
                "destination": PropertySchema(type: "string")
            ]
        )
    }

    public func execute(input: String, context: ToolExecutionContext) async throws -> String {
        let params = try JSONDecoder().decode(Input.self, from: Data(input.utf8))
        let source = try context.validatePathForWrite(params.source)
        let dest = try context.validatePathForWrite(params.destination)

        let fm = await context.serviceProvider.getFileManager()
        try await fm.move(from: source, to: dest)

        let output = Output(success: true, destination: params.destination)
        return try encodeJSON(output)
    }

    struct Input: Codable {
        let source: String
        let destination: String
    }

    struct Output: Codable {
        let success: Bool
        let destination: String
    }
}

public struct CopyFileTool: AgentTool {
    public init() {}

    nonisolated public static let toolName = "copy_file"
    nonisolated public static let toolDescription = "Copy a file to a new location"

    nonisolated public static var inputSchema: ToolInputSchema {
        ToolInputSchema(
            properties: [
                "source": PropertySchema(type: "string", description: "Source file path"),
                "destination": PropertySchema(type: "string", description: "Destination file path")
            ],
            required: ["source", "destination"]
        )
    }

    nonisolated public static var outputSchema: ToolOutputSchema {
        ToolOutputSchema(
            properties: [
                "success": PropertySchema(type: "boolean"),
                "destination": PropertySchema(type: "string")
            ]
        )
    }

    public func execute(input: String, context: ToolExecutionContext) async throws -> String {
        let params = try JSONDecoder().decode(Input.self, from: Data(input.utf8))
        let source = try context.validatePathForRead(params.source)
        let dest = try context.validatePathForWrite(params.destination)

        let fm = await context.serviceProvider.getFileManager()
        try await fm.copy(from: source, to: dest)

        let output = Output(success: true, destination: params.destination)
        return try encodeJSON(output)
    }

    struct Input: Codable {
        let source: String
        let destination: String
    }

    struct Output: Codable {
        let success: Bool
        let destination: String
    }
}

public struct ReadFileChunkTool: AgentTool {
    public init() {}

    nonisolated public static let toolName = "read_file_chunk"
    nonisolated public static let toolDescription = "Read a specific byte range from a file"

    nonisolated public static var inputSchema: ToolInputSchema {
        ToolInputSchema(
            properties: [
                "path": PropertySchema(type: "string", description: "Absolute path to the file"),
                "offset": PropertySchema(type: "integer", description: "Byte offset to start reading"),
                "length": PropertySchema(type: "integer", description: "Number of bytes to read"),
                "encoding": PropertySchema(type: "string", description: "Encoding: 'utf8' or 'base64'",
                                            defaultValue: "utf8")
            ],
            required: ["path", "offset", "length"]
        )
    }

    nonisolated public static var outputSchema: ToolOutputSchema {
        ToolOutputSchema(
            properties: [
                "content": PropertySchema(type: "string"),
                "offset": PropertySchema(type: "integer"),
                "length": PropertySchema(type: "integer")
            ]
        )
    }

    public func execute(input: String, context: ToolExecutionContext) async throws -> String {
        let params = try JSONDecoder().decode(Input.self, from: Data(input.utf8))
        let url = try context.validatePathForRead(params.path)
        let fm = await context.serviceProvider.getFileManager()

        guard params.offset >= 0, params.length > 0 else {
            throw ToolError.invalidInput("Offset must be non-negative and length must be positive")
        }

        // Check chunk size against limits
        try context.checkReadSize(params.length)
        let data = try await fm.read(from: url)
        try context.checkReadSize(data.count)

        let chunk: Data
        if params.offset >= data.count {
            chunk = Data()
        } else {
            let end = min(data.count, params.offset + params.length)
            chunk = data.subdata(in: params.offset..<end)
        }

        let encoding = params.encoding ?? "utf8"
        let content: String
        if encoding == "base64" {
            content = chunk.base64EncodedString()
        } else {
            guard let utf8Content = String(data: chunk, encoding: .utf8) else {
                throw ToolError.invalidInput("File chunk contains non-UTF8 binary data. Use 'base64' encoding.")
            }
            content = utf8Content
        }

        let output = Output(content: content, offset: params.offset, length: chunk.count)
        return try encodeJSON(output)
    }

    struct Input: Codable {
        let path: String
        let offset: Int
        let length: Int
        let encoding: String?
    }

    struct Output: Codable {
        let content: String
        let offset: Int
        let length: Int
    }
}

// MARK: - Directory Operations

public struct ListDirectoryTool: AgentTool {
    public init() {}

    nonisolated public static let toolName = "list_directory"
    nonisolated public static let toolDescription = "List files and subdirectories in a directory"

    nonisolated public static var inputSchema: ToolInputSchema {
        ToolInputSchema(
            properties: [
                "path": PropertySchema(type: "string", description: "Absolute path to directory"),
                "recursive": PropertySchema(type: "boolean", description: "List recursively", defaultValue: "false")
            ],
            required: ["path"]
        )
    }

    nonisolated public static var outputSchema: ToolOutputSchema {
        ToolOutputSchema(
            properties: [
                "entries": PropertySchema(type: "array", items: PropertySchema(type: "object")),
                "totalCount": PropertySchema(type: "integer")
            ]
        )
    }

    public func execute(input: String, context: ToolExecutionContext) async throws -> String {
        let params = try JSONDecoder().decode(Input.self, from: Data(input.utf8))
        let url = try context.validatePathForRead(params.path)
        let fm = await context.serviceProvider.getFileManager()

        var entries: [Entry] = []
        let items = params.recursive == true
            ? try await fm.listDirectoryRecursive(at: url)
            : try await fm.listDirectory(at: url)

        for item in items {
            let attrs = try? await fm.attributesOfItem(atPath: item.path)
            let isDir = fileAttributeTypeString(from: attrs ?? [:]) == FileAttributeType.typeDirectory.rawValue
            entries.append(Entry(name: item.lastPathComponent, path: item.path, isDirectory: isDir))
        }

        let output = Output(entries: entries, totalCount: entries.count)
        return try encodeJSON(output)
    }

    struct Input: Codable {
        let path: String
        let recursive: Bool?
    }

    struct Entry: Codable {
        let name: String
        let path: String
        let isDirectory: Bool
    }

    struct Output: Codable {
        let entries: [Entry]
        let totalCount: Int
    }
}

public struct CreateDirectoryTool: AgentTool {
    public init() {}

    nonisolated public static let toolName = "create_directory"
    nonisolated public static let toolDescription = "Create a new directory"

    nonisolated public static var inputSchema: ToolInputSchema {
        ToolInputSchema(
            properties: [
                "path": PropertySchema(type: "string", description: "Absolute path for new directory"),
                "intermediate": PropertySchema(type: "boolean", description: "Create intermediate directories",
                                            defaultValue: "true")
            ],
            required: ["path"]
        )
    }

    nonisolated public static var outputSchema: ToolOutputSchema {
        ToolOutputSchema(
            properties: [
                "success": PropertySchema(type: "boolean"),
                "path": PropertySchema(type: "string")
            ]
        )
    }

    public func execute(input: String, context: ToolExecutionContext) async throws -> String {
        let params = try JSONDecoder().decode(Input.self, from: Data(input.utf8))
        let url = try context.validatePathForWrite(params.path)
        let fm = await context.serviceProvider.getFileManager()

        if params.intermediate == false {
            let parent = url.deletingLastPathComponent()
            guard await fm.exists(at: parent) else {
                throw ToolError.invalidInput("Parent directory does not exist: \(parent.path)")
            }
        }

        try await fm.createDirectory(at: url)

        let output = Output(success: true, path: params.path)
        return try encodeJSON(output)
    }

    struct Input: Codable {
        let path: String
        let intermediate: Bool?
    }

    struct Output: Codable {
        let success: Bool
        let path: String
    }
}

public struct DeleteDirectoryTool: AgentTool {
    public init() {}

    nonisolated public static let toolName = "delete_directory"
    nonisolated public static let toolDescription = "Delete a directory and all its contents"

    nonisolated public static var inputSchema: ToolInputSchema {
        ToolInputSchema(
            properties: [
                "path": PropertySchema(type: "string", description: "Absolute path to directory")
            ],
            required: ["path"]
        )
    }

    nonisolated public static var outputSchema: ToolOutputSchema {
        ToolOutputSchema(
            properties: [
                "success": PropertySchema(type: "boolean"),
                "path": PropertySchema(type: "string")
            ]
        )
    }

    public func execute(input: String, context: ToolExecutionContext) async throws -> String {
        let params = try JSONDecoder().decode(Input.self, from: Data(input.utf8))
        let url = try context.validatePathForWrite(params.path)

        let fm = await context.serviceProvider.getFileManager()
        try await fm.delete(at: url)

        let output = Output(success: true, path: params.path)
        return try encodeJSON(output)
    }

    struct Input: Codable {
        let path: String
    }

    struct Output: Codable {
        let success: Bool
        let path: String
    }
}

public struct SearchFilesTool: AgentTool {
    public init() {}

    nonisolated public static let toolName = "search_files"
    nonisolated public static let toolDescription = "Search for files matching a pattern"

    nonisolated public static var inputSchema: ToolInputSchema {
        ToolInputSchema(
            properties: [
                "directory": PropertySchema(type: "string", description: "Directory to search in"),
                "pattern": PropertySchema(type: "string", description: "Glob pattern (e.g., '*.swift')"),
                "recursive": PropertySchema(type: "boolean", description: "Search recursively", defaultValue: "true")
            ],
            required: ["directory", "pattern"]
        )
    }

    nonisolated public static var outputSchema: ToolOutputSchema {
        ToolOutputSchema(
            properties: [
                "matches": PropertySchema(type: "array", items: PropertySchema(type: "string"))
            ]
        )
    }

    public func execute(input: String, context: ToolExecutionContext) async throws -> String {
        let params = try JSONDecoder().decode(Input.self, from: Data(input.utf8))
        let fm = await context.serviceProvider.getFileManager()
        let dir = try context.validatePathForRead(params.directory)

        var matches: [String] = []
        let limits = ToolLimits.default

        let items: [URL] = if params.recursive == false {
            try await fm.listDirectory(at: dir)
        } else {
            try await fm.listDirectoryRecursive(at: dir)
        }
        let matched = items
            .filter { $0.lastPathComponent.matchesPattern(params.pattern) }
            .prefix(limits.maxSearchResults)
        matches.append(contentsOf: matched.map(\.path))

        let output = Output(matches: matches)
        return try encodeJSON(output)
    }

    struct Input: Codable {
        let directory: String
        let pattern: String
        let recursive: Bool?
    }

    struct Output: Codable {
        let matches: [String]
    }
}

// MARK: - Path Operations

public struct PathExistsTool: AgentTool {
    public init() {}

    nonisolated public static let toolName = "path_exists"
    nonisolated public static let toolDescription = "Check if a path exists and what type it is"

    nonisolated public static var inputSchema: ToolInputSchema {
        ToolInputSchema(
            properties: [
                "path": PropertySchema(type: "string", description: "Absolute path to check")
            ],
            required: ["path"]
        )
    }

    nonisolated public static var outputSchema: ToolOutputSchema {
        ToolOutputSchema(
            properties: [
                "exists": PropertySchema(type: "boolean"),
                "type": PropertySchema(type: "string", description: "'file', 'directory', or 'none'")
            ]
        )
    }

    public func execute(input: String, context: ToolExecutionContext) async throws -> String {
        let params = try JSONDecoder().decode(Input.self, from: Data(input.utf8))
        let url = try context.validatePathForRead(params.path)
        let fm = await context.serviceProvider.getFileManager()

        let exists = await fm.exists(at: url)
        var type = "none"

        if exists {
            let attrs = try? await fm.attributesOfItem(atPath: url.path)
            if let dirAttr = fileAttributeTypeString(from: attrs ?? [:]) {
                type = dirAttr == FileAttributeType.typeDirectory.rawValue ? "directory" : "file"
            }
        }

        let output = Output(exists: exists, type: type)
        return try encodeJSON(output)
    }

    struct Input: Codable {
        let path: String
    }

    struct Output: Codable {
        let exists: Bool
        let type: String
    }
}

public struct GetFileInfoTool: AgentTool {
    public init() {}

    nonisolated public static let toolName = "get_file_info"
    nonisolated public static let toolDescription = "Get metadata about a file (size, modification date)"

    nonisolated public static var inputSchema: ToolInputSchema {
        ToolInputSchema(
            properties: [
                "path": PropertySchema(type: "string", description: "Absolute path to the file")
            ],
            required: ["path"]
        )
    }

    nonisolated public static var outputSchema: ToolOutputSchema {
        ToolOutputSchema(
            properties: [
                "size": PropertySchema(type: "integer"),
                "created": PropertySchema(type: "string"),
                "modified": PropertySchema(type: "string"),
                "isDirectory": PropertySchema(type: "boolean")
            ]
        )
    }

    public func execute(input: String, context: ToolExecutionContext) async throws -> String {
        let params = try JSONDecoder().decode(Input.self, from: Data(input.utf8))
        let url = try context.validatePathForRead(params.path)
        let fm = await context.serviceProvider.getFileManager()

        guard await fm.exists(at: url) else {
            throw ToolError.invalidInput("Path does not exist: \(params.path)")
        }

        let attrs = try await fm.attributesOfItem(atPath: url.path)
        let size = attrs[.size] as? Int ?? 0
        let created = (attrs[.creationDate] as? Date)?.ISO8601Format() ?? ""
        let modified = (attrs[.modificationDate] as? Date)?.ISO8601Format() ?? ""
        let isDir = fileAttributeTypeString(from: attrs) == FileAttributeType.typeDirectory.rawValue

        let output = Output(size: size, created: created, modified: modified, isDirectory: isDir)
        return try encodeJSON(output)
    }

    struct Input: Codable {
        let path: String
    }

    struct Output: Codable {
        let size: Int
        let created: String
        let modified: String
        let isDirectory: Bool
    }
}

// MARK: - System/Environment

public struct RunCommandTool: AgentTool {
    public init() {}

    nonisolated public static let toolName = "run_command"
    nonisolated public static let toolDescription = "Execute a shell command"

    nonisolated public static var inputSchema: ToolInputSchema {
        ToolInputSchema(
            properties: [
                "command": PropertySchema(type: "string", description: "Command to execute"),
                "cwd": PropertySchema(type: "string", description: "Working directory for command"),
                "timeout": PropertySchema(type: "integer", description: "Timeout in seconds", defaultValue: "30")
            ],
            required: ["command"]
        )
    }

    nonisolated public static var outputSchema: ToolOutputSchema {
        ToolOutputSchema(
            properties: [
                "stdout": PropertySchema(type: "string"),
                "stderr": PropertySchema(type: "string"),
                "exitCode": PropertySchema(type: "integer")
            ]
        )
    }

    public func execute(input: String, context: ToolExecutionContext) async throws -> String {
        let params = try JSONDecoder().decode(Input.self, from: Data(input.utf8))
        let limits = ToolLimits.default
        let timeout = min(params.timeout ?? limits.defaultCommandTimeout, limits.maxCommandTimeout)

        // Validate command
        let validator = CommandValidator()
        let validation = validator.validate(params.command, allowUnsafe: false)

        let cmd: CommandValidator.ParsedCommand
        switch validation {
        case .success(let parsed):
            cmd = parsed

        case .failure(let error):
            throw ToolError.invalidInput("Command not allowed: \(error.message)")
        }

        // Validate and set working directory
        let cwdURL: URL
        if let cwd = params.cwd {
            cwdURL = try context.validatePathForRead(cwd)
        } else {
            cwdURL = context.workingDirectory
        }

        // Use injected command executor
        let executor = await context.serviceProvider.getCommandExecutor()

        // Resolve command path
        let executablePath = try await executor.resolvePath(
            command: cmd.executable,
            environment: context.environment,
            timeout: timeout
        )

        // Execute command with timeout handled by executor
        let result = try await executor.execute(
            command: executablePath,
            arguments: cmd.args,
            workingDirectory: cwdURL,
            environment: context.environment,
            timeout: timeout
        )

        // Limit output size
        let truncatedOut = result.stdout.count > limits.maxCommandOutput
            ? String(result.stdout.prefix(limits.maxCommandOutput))
            : result.stdout
        let truncatedErr = result.stderr.count > limits.maxCommandOutput
            ? String(result.stderr.prefix(limits.maxCommandOutput))
            : result.stderr

        let output = Output(
            stdout: truncatedOut,
            stderr: truncatedErr,
            exitCode: result.exitCode
        )
        return try encodeJSON(output)
    }

    struct Input: Codable {
        let command: String
        let cwd: String?
        let timeout: Int?
    }

    struct Output: Codable {
        let stdout: String
        let stderr: String
        let exitCode: Int
    }
}

public struct GetEnvironmentTool: AgentTool {
    public init() {}

    nonisolated public static let toolName = "get_environment"
    nonisolated public static let toolDescription = "Get environment variables"

    nonisolated public static var inputSchema: ToolInputSchema {
        ToolInputSchema(
            properties: [
                "key": PropertySchema(type: "string", description: "Specific variable to get (omit for all)")
            ]
        )
    }

    nonisolated public static var outputSchema: ToolOutputSchema {
        ToolOutputSchema(
            properties: [
                "variables": PropertySchema(type: "object"),
                "value": PropertySchema(type: "string")
            ]
        )
    }

    public func execute(input: String, context: ToolExecutionContext) async throws -> String {
        let params = try JSONDecoder().decode(Input.self, from: Data(input.utf8))

        if let key = params.key {
            let value = context.environment[key] ?? ""
            let output = SingleOutput(value: value)
            return try encodeJSON(output)
        } else {
            let output = AllOutput(variables: context.environment)
            return try encodeJSON(output)
        }
    }

    struct Input: Codable {
        let key: String?
    }

    struct AllOutput: Codable {
        let variables: [String: String]
    }

    struct SingleOutput: Codable {
        let value: String
    }
}

public struct GetWorkingDirectoryTool: AgentTool {
    public init() {}

    nonisolated public static let toolName = "get_working_directory"
    nonisolated public static let toolDescription = "Get the current working directory"

    nonisolated public static var inputSchema: ToolInputSchema {
        ToolInputSchema(properties: [:])
    }

    nonisolated public static var outputSchema: ToolOutputSchema {
        ToolOutputSchema(
            properties: [
                "path": PropertySchema(type: "string")
            ]
        )
    }

    public func execute(input: String, context: ToolExecutionContext) async throws -> String {
        let output = Output(path: context.workingDirectory.path)
        return try encodeJSON(output)
    }

    struct Output: Codable {
        let path: String
    }
}

// MARK: - Command Executor Implementation

struct RealCommandExecutor: CommandExecutor {

    func execute(
        command: String,
        arguments: [String],
        workingDirectory: URL,
        environment: [String: String],
        timeout: Int
    ) async throws -> (stdout: String, stderr: String, exitCode: Int) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments
        process.currentDirectoryURL = workingDirectory
        process.environment = environment

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        return try await withTimeout(seconds: timeout) {
            try process.run()
            process.waitUntilExit()

            let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

            let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
            let stderr = String(data: stderrData, encoding: .utf8) ?? ""

            return (stdout, stderr, Int(process.terminationStatus))
        }
    }

    func resolvePath(command: String, environment: [String: String], timeout: Int) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [command]
        process.environment = environment

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        return try await withTimeout(seconds: timeout) {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !path.isEmpty else {
                throw ToolError.invalidInput("Command '\(command)' not found in PATH")
            }
            return path
        }
    }

    private func withTimeout<T: Sendable>(
        seconds: Int,
        operation: @Sendable @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds) * 1_000_000_000)
                throw ToolError.timeout
            }
            guard let result = try await group.next() else {
                throw ToolError.timeout
            }
            group.cancelAll()
            return result
        }
    }
}

// MARK: - Helpers

extension String {
    func matchesPattern(_ pattern: String) -> Bool {
        let regex = pattern
            .replacingOccurrences(of: ".", with: "\\.")
            .replacingOccurrences(of: "*", with: ".*")
            .replacingOccurrences(of: "?", with: ".")
        return self.range(of: "^\(regex)$", options: .regularExpression) != nil
    }
}
