import Foundation

// MARK: - Constants

private enum Encoding: String {
    case utf8 = "utf8"
    case base64 = "base64"
}

private enum FileMode: String {
    case overwrite = "overwrite"
    case append = "append"
}

// MARK: - Helpers

private func encodeJSON<T: Encodable>(_ value: T) throws -> String {
    String(decoding: try JSONEncoder().encode(value), as: UTF8.self)
}

// MARK: - File Operations

public struct ReadFileTool: AgentTool {
    public init() {}

    public nonisolated static let toolName = "read_file"
    public nonisolated static let toolDescription = "Read the contents of a file as text or base64"

    public nonisolated static var inputSchema: ToolInputSchema {
        ToolInputSchema(
            properties: [
                "path": PropertySchema(type: "string", description: "Absolute path to the file"),
                "encoding": PropertySchema(type: "string", description: "Encoding: 'utf8' or 'base64'", defaultValue: "utf8")
            ],
            required: ["path"]
        )
    }

    public nonisolated static var outputSchema: ToolOutputSchema {
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

        // Check file size before reading
        let fm = FileManager.default
        if let attrs = try? fm.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int {
            try context.checkReadSize(size)
        }

        let data = try await context.serviceProvider.getFileManager().read(from: url)
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

    public nonisolated static let toolName = "create_file"
    public nonisolated static let toolDescription = "Create a new file with the given content"

    public nonisolated static var inputSchema: ToolInputSchema {
        ToolInputSchema(
            properties: [
                "path": PropertySchema(type: "string", description: "Absolute path for the new file"),
                "content": PropertySchema(type: "string", description: "File content"),
                "encoding": PropertySchema(type: "string", description: "Encoding: 'utf8' or 'base64'", defaultValue: "utf8")
            ],
            required: ["path", "content"]
        )
    }

    public nonisolated static var outputSchema: ToolOutputSchema {
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
        try await context.serviceProvider.getFileManager().write(data: data, to: url)

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

    public nonisolated static let toolName = "write_file"
    public nonisolated static let toolDescription = "Write or append content to a file"

    public nonisolated static var inputSchema: ToolInputSchema {
        ToolInputSchema(
            properties: [
                "path": PropertySchema(type: "string", description: "Absolute path to the file"),
                "content": PropertySchema(type: "string", description: "Content to write"),
                "mode": PropertySchema(type: "string", description: "'overwrite' or 'append'", defaultValue: "overwrite"),
                "encoding": PropertySchema(type: "string", description: "Encoding: 'utf8' or 'base64'", defaultValue: "utf8")
            ],
            required: ["path", "content"]
        )
    }

    public nonisolated static var outputSchema: ToolOutputSchema {
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
        let fm = context.serviceProvider.getFileManager()

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

    public nonisolated static let toolName = "delete_file"
    public nonisolated static let toolDescription = "Delete a file"

    public nonisolated static var inputSchema: ToolInputSchema {
        ToolInputSchema(
            properties: [
                "path": PropertySchema(type: "string", description: "Absolute path to the file")
            ],
            required: ["path"]
        )
    }

    public nonisolated static var outputSchema: ToolOutputSchema {
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

        try await context.serviceProvider.getFileManager().delete(at: url)

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

    public nonisolated static let toolName = "move_file"
    public nonisolated static let toolDescription = "Move or rename a file"

    public nonisolated static var inputSchema: ToolInputSchema {
        ToolInputSchema(
            properties: [
                "source": PropertySchema(type: "string", description: "Source file path"),
                "destination": PropertySchema(type: "string", description: "Destination file path")
            ],
            required: ["source", "destination"]
        )
    }

    public nonisolated static var outputSchema: ToolOutputSchema {
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

        // Use FileManager for atomic move (handles large files efficiently)
        let fileManager = FileManager.default
        try fileManager.moveItem(at: source, to: dest)

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

    public nonisolated static let toolName = "copy_file"
    public nonisolated static let toolDescription = "Copy a file to a new location"

    public nonisolated static var inputSchema: ToolInputSchema {
        ToolInputSchema(
            properties: [
                "source": PropertySchema(type: "string", description: "Source file path"),
                "destination": PropertySchema(type: "string", description: "Destination file path")
            ],
            required: ["source", "destination"]
        )
    }

    public nonisolated static var outputSchema: ToolOutputSchema {
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

        // Use FileManager for efficient copy (handles large files without loading to memory)
        let fileManager = FileManager.default
        try fileManager.copyItem(at: source, to: dest)

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

    public nonisolated static let toolName = "read_file_chunk"
    public nonisolated static let toolDescription = "Read a specific byte range from a file"

    public nonisolated static var inputSchema: ToolInputSchema {
        ToolInputSchema(
            properties: [
                "path": PropertySchema(type: "string", description: "Absolute path to the file"),
                "offset": PropertySchema(type: "integer", description: "Byte offset to start reading"),
                "length": PropertySchema(type: "integer", description: "Number of bytes to read"),
                "encoding": PropertySchema(type: "string", description: "Encoding: 'utf8' or 'base64'", defaultValue: "utf8")
            ],
            required: ["path", "offset", "length"]
        )
    }

    public nonisolated static var outputSchema: ToolOutputSchema {
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

        guard params.offset >= 0, params.length > 0 else {
            throw ToolError.invalidInput("Offset must be non-negative and length must be positive")
        }

        // Check chunk size against limits
        try context.checkReadSize(params.length)

        // Use FileHandle for seeking to avoid loading entire file
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        // Seek to offset
        if #available(macOS 10.15.4, iOS 13.4, watchOS 6.2, tvOS 13.4, *) {
            try handle.seek(toOffset: UInt64(params.offset))
        } else {
            handle.seek(toFileOffset: UInt64(params.offset))
        }

        // Read requested length
        let chunk = handle.readData(ofLength: params.length)

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

    public nonisolated static let toolName = "list_directory"
    public nonisolated static let toolDescription = "List files and subdirectories in a directory"

    public nonisolated static var inputSchema: ToolInputSchema {
        ToolInputSchema(
            properties: [
                "path": PropertySchema(type: "string", description: "Absolute path to directory"),
                "recursive": PropertySchema(type: "boolean", description: "List recursively", defaultValue: "false")
            ],
            required: ["path"]
        )
    }

    public nonisolated static var outputSchema: ToolOutputSchema {
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
        let fm = context.serviceProvider.getFileManager()

        var entries: [Entry] = []
        let items = try await fm.listDirectory(at: url)

        for item in items {
            // Use FileManager to check if directory without masking errors
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: item.path, isDirectory: &isDir)
            entries.append(Entry(name: item.lastPathComponent, path: item.path, isDirectory: isDir.boolValue))

            if params.recursive == true, isDir.boolValue {
                // Could recurse here, keeping simple for now
            }
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

    public nonisolated static let toolName = "create_directory"
    public nonisolated static let toolDescription = "Create a new directory"

    public nonisolated static var inputSchema: ToolInputSchema {
        ToolInputSchema(
            properties: [
                "path": PropertySchema(type: "string", description: "Absolute path for new directory"),
                "intermediate": PropertySchema(type: "boolean", description: "Create intermediate directories", defaultValue: "true")
            ],
            required: ["path"]
        )
    }

    public nonisolated static var outputSchema: ToolOutputSchema {
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
        let fm = context.serviceProvider.getFileManager()

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

    public nonisolated static let toolName = "delete_directory"
    public nonisolated static let toolDescription = "Delete a directory and all its contents"

    public nonisolated static var inputSchema: ToolInputSchema {
        ToolInputSchema(
            properties: [
                "path": PropertySchema(type: "string", description: "Absolute path to directory")
            ],
            required: ["path"]
        )
    }

    public nonisolated static var outputSchema: ToolOutputSchema {
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

        try await context.serviceProvider.getFileManager().delete(at: url)

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

    public nonisolated static let toolName = "search_files"
    public nonisolated static let toolDescription = "Search for files matching a pattern"

    public nonisolated static var inputSchema: ToolInputSchema {
        ToolInputSchema(
            properties: [
                "directory": PropertySchema(type: "string", description: "Directory to search in"),
                "pattern": PropertySchema(type: "string", description: "Glob pattern (e.g., '*.swift')"),
                "recursive": PropertySchema(type: "boolean", description: "Search recursively", defaultValue: "true")
            ],
            required: ["directory", "pattern"]
        )
    }

    public nonisolated static var outputSchema: ToolOutputSchema {
        ToolOutputSchema(
            properties: [
                "matches": PropertySchema(type: "array", items: PropertySchema(type: "string"))
            ]
        )
    }

    public func execute(input: String, context: ToolExecutionContext) async throws -> String {
        let params = try JSONDecoder().decode(Input.self, from: Data(input.utf8))
        let fm = context.serviceProvider.getFileManager()
        let dir = try context.validatePathForRead(params.directory)

        var matches: [String] = []
        let limits = ToolLimits.default

        if params.recursive == false {
            let items = try await fm.listDirectory(at: dir)
            for item in items {
                if item.lastPathComponent.matchesPattern(params.pattern) {
                    matches.append(item.path)
                    if matches.count >= limits.maxSearchResults {
                        break
                    }
                }
            }
        } else {
            let fileManager = FileManager.default
            let enumerator = fileManager.enumerator(at: dir, includingPropertiesForKeys: nil)
            while let url = enumerator?.nextObject() as? URL {
                if url.lastPathComponent.matchesPattern(params.pattern) {
                    matches.append(url.path)
                    if matches.count >= limits.maxSearchResults {
                        break
                    }
                }
            }
        }

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

    public nonisolated static let toolName = "path_exists"
    public nonisolated static let toolDescription = "Check if a path exists and what type it is"

    public nonisolated static var inputSchema: ToolInputSchema {
        ToolInputSchema(
            properties: [
                "path": PropertySchema(type: "string", description: "Absolute path to check")
            ],
            required: ["path"]
        )
    }

    public nonisolated static var outputSchema: ToolOutputSchema {
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
        let fm = context.serviceProvider.getFileManager()

        let exists = await fm.exists(at: url)
        var type = "none"

        if exists {
            let fileManager = FileManager.default
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: url.path, isDirectory: &isDir) {
                type = isDir.boolValue ? "directory" : "file"
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

    public nonisolated static let toolName = "get_file_info"
    public nonisolated static let toolDescription = "Get metadata about a file (size, modification date)"

    public nonisolated static var inputSchema: ToolInputSchema {
        ToolInputSchema(
            properties: [
                "path": PropertySchema(type: "string", description: "Absolute path to the file")
            ],
            required: ["path"]
        )
    }

    public nonisolated static var outputSchema: ToolOutputSchema {
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
        let fm = context.serviceProvider.getFileManager()

        guard await fm.exists(at: url) else {
            throw ToolError.invalidInput("Path does not exist: \(params.path)")
        }

        let fileManager = FileManager.default
        let attrs = try fileManager.attributesOfItem(atPath: url.path)
        let size = attrs[.size] as? Int ?? 0
        let created = (attrs[.creationDate] as? Date)?.ISO8601Format() ?? ""
        let modified = (attrs[.modificationDate] as? Date)?.ISO8601Format() ?? ""
        let isDir = (attrs[.type] as? FileAttributeType) == .typeDirectory

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

    public nonisolated static let toolName = "run_command"
    public nonisolated static let toolDescription = "Execute a shell command"

    public nonisolated static var inputSchema: ToolInputSchema {
        ToolInputSchema(
            properties: [
                "command": PropertySchema(type: "string", description: "Command to execute"),
                "cwd": PropertySchema(type: "string", description: "Working directory for command"),
                "timeout": PropertySchema(type: "integer", description: "Timeout in seconds", defaultValue: "30")
            ],
            required: ["command"]
        )
    }

    public nonisolated static var outputSchema: ToolOutputSchema {
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

        let process = Process()

        switch validation {
        case .success(let cmd):
            // Safe command - execute directly without shell
            // Search PATH for executable using 'which'
            let whichProcess = Process()
            whichProcess.executableURL = URL(fileURLWithPath: "/usr/bin/which")
            whichProcess.arguments = [cmd.executable]
            whichProcess.environment = context.environment

            let whichPipe = Pipe()
            whichProcess.standardOutput = whichPipe
            try whichProcess.run()
            whichProcess.waitUntilExit()

            guard whichProcess.terminationStatus == 0 else {
                throw ToolError.invalidInput("Command '\(cmd.executable)' not found in PATH")
            }

            let whichData = whichPipe.fileHandleForReading.readDataToEndOfFile()
            guard let executablePath = String(data: whichData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !executablePath.isEmpty else {
                throw ToolError.invalidInput("Could not resolve path for '\(cmd.executable)'")
            }

            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = cmd.args
        case .failure(let error):
            // Unsafe command - reject with specific reason
            throw ToolError.invalidInput("Command not allowed: \(error.message)")
        }

        // Validate and set working directory
        let cwdURL: URL
        if let cwd = params.cwd {
            cwdURL = try context.validatePathForRead(cwd)
        } else {
            cwdURL = context.workingDirectory
        }
        process.currentDirectoryURL = cwdURL

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        let task = Task {
            try process.run()
            process.waitUntilExit()
            let outData = stdout.fileHandleForReading.readDataToEndOfFile()
            let errData = stderr.fileHandleForReading.readDataToEndOfFile()
            // Limit output size
            let truncatedOut = outData.count > limits.maxCommandOutput ?
                Data(outData.prefix(limits.maxCommandOutput)) : outData
            let truncatedErr = errData.count > limits.maxCommandOutput ?
                Data(errData.prefix(limits.maxCommandOutput)) : errData
            return (stdout: truncatedOut, stderr: truncatedErr, exitCode: Int(process.terminationStatus))
        }

        let result: (stdout: Data, stderr: Data, exitCode: Int)
        do {
            result = try await withTimeout(seconds: timeout) {
                try await task.value
            }
        } catch ToolError.timeout {
            process.terminate()
            throw ToolError.timeout
        }

        let output = Output(
            stdout: String(decoding: result.stdout, as: UTF8.self),
            stderr: String(decoding: result.stderr, as: UTF8.self),
            exitCode: result.exitCode
        )
        return try encodeJSON(output)
    }

    private func withTimeout<T: Sendable>(seconds: Int, operation: @Sendable @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds) * 1_000_000_000)
                throw ToolError.timeout
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
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

    public nonisolated static let toolName = "get_environment"
    public nonisolated static let toolDescription = "Get environment variables"

    public nonisolated static var inputSchema: ToolInputSchema {
        ToolInputSchema(
            properties: [
                "key": PropertySchema(type: "string", description: "Specific variable to get (omit for all)")
            ]
        )
    }

    public nonisolated static var outputSchema: ToolOutputSchema {
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

    public nonisolated static let toolName = "get_working_directory"
    public nonisolated static let toolDescription = "Get the current working directory"

    public nonisolated static var inputSchema: ToolInputSchema {
        ToolInputSchema(properties: [:])
    }

    public nonisolated static var outputSchema: ToolOutputSchema {
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

// MARK: - Helpers

extension String {
    func matchesPattern(_ pattern: String) -> Bool {
        let regex = pattern
            .replacingOccurrences(of: ".", with: "\\.")
            .replacingOccurrences(of: "*", with: ".*")
            .replacingOccurrences(of: "?", with: ".")
        return self.range(of: regex, options: .regularExpression) != nil
    }
}
