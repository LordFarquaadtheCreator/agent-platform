import XCTest
@testable import senor_platform

// swiftlint:disable force_try

private struct ReadResponse: Decodable {
    let content: String
    let encoding: String
}

private struct ChunkResponse: Decodable {
    let content: String
    let offset: Int
    let length: Int
}

private struct EntriesResponse: Decodable {
    struct Entry: Decodable {
        let name: String
        let path: String
        let isDirectory: Bool
    }

    let entries: [Entry]
    let totalCount: Int
}

private struct MatchesResponse: Decodable {
    let matches: [String]
}

private struct ExistsResponse: Decodable {
    let exists: Bool
    let type: String
}

private struct FileInfoResponse: Decodable {
    let size: Int
    let created: String
    let modified: String
    let isDirectory: Bool
}

private struct CommandResponse: Decodable {
    let stdout: String
    let stderr: String
    let exitCode: Int
}

private struct EnvironmentValueResponse: Decodable {
    let value: String
}

private struct EnvironmentMapResponse: Decodable {
    let variables: [String: String]
}

private struct WorkingDirectoryResponse: Decodable {
    let path: String
}

actor MockFileManager: ToolFileManager {
    private var files: [URL: Data] = [:]
    private var directories: Set<URL> = []
    private var customAttributes: [URL: [FileAttributeKey: Any]] = [:]

    func createDirectory(at url: URL) async throws {
        directories.insert(url.standardizedFileURL)
        directories.insert(url.deletingLastPathComponent().standardizedFileURL)
    }

    func write(data: Data, to url: URL) async throws {
        let normalized = url.standardizedFileURL
        files[normalized] = data
        directories.insert(normalized.deletingLastPathComponent())
    }

    func read(from url: URL) async throws -> Data {
        let normalized = url.standardizedFileURL
        guard let data = files[normalized] else {
            throw ToolError.fileError(NSError(
                domain: "MockFileManager",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "File not found: \(normalized.path)"]
            ))
        }
        return data
    }

    func exists(at url: URL) async -> Bool {
        let normalized = url.standardizedFileURL
        return files[normalized] != nil || directories.contains(normalized)
    }

    func delete(at url: URL) async throws {
        let normalized = url.standardizedFileURL
        files = files.filter { key, _ in
            key != normalized && !key.path.hasPrefix(normalized.path + "/")
        }
        directories = directories.filter { dir in
            dir != normalized && !dir.path.hasPrefix(normalized.path + "/")
        }
        customAttributes = customAttributes.filter { key, _ in
            key != normalized && !key.path.hasPrefix(normalized.path + "/")
        }
    }

    func move(from source: URL, to dest: URL) async throws {
        let sourceURL = source.standardizedFileURL
        let destURL = dest.standardizedFileURL

        if let data = files.removeValue(forKey: sourceURL) {
            files[destURL] = data
            customAttributes[destURL] = customAttributes.removeValue(forKey: sourceURL)
            directories.insert(destURL.deletingLastPathComponent())
            return
        }

        guard directories.contains(sourceURL) else {
            throw ToolError.fileError(NSError(domain: "MockFileManager", code: 4))
        }

        directories.remove(sourceURL)
        directories.insert(destURL)
    }

    func copy(from source: URL, to dest: URL) async throws {
        let sourceURL = source.standardizedFileURL
        let destURL = dest.standardizedFileURL

        guard let data = files[sourceURL] else {
            throw ToolError.fileError(NSError(domain: "MockFileManager", code: 5))
        }

        files[destURL] = data
        customAttributes[destURL] = customAttributes[sourceURL]
        directories.insert(destURL.deletingLastPathComponent())
    }

    func listDirectory(at url: URL) async throws -> [URL] {
        let normalized = url.standardizedFileURL
        guard directories.contains(normalized) else {
            throw ToolError.fileError(NSError(domain: "MockFileManager", code: 2))
        }

        let childFiles = files.keys.filter { $0.deletingLastPathComponent() == normalized }
        let childDirectories = directories.filter {
            $0.deletingLastPathComponent() == normalized && $0 != normalized
        }
        return Array(Set(childFiles + childDirectories)).sorted { $0.path < $1.path }
    }

    func listDirectoryRecursive(at url: URL) async throws -> [URL] {
        let normalized = url.standardizedFileURL
        guard directories.contains(normalized) else {
            throw ToolError.fileError(NSError(domain: "MockFileManager", code: 2))
        }

        let childFiles = files.keys.filter { $0.path.hasPrefix(normalized.path + "/") }
        let childDirectories = directories.filter {
            $0 != normalized && $0.path.hasPrefix(normalized.path + "/")
        }
        return Array(Set(childFiles + childDirectories)).sorted { $0.path < $1.path }
    }

    func createTempFile(prefix: String, suffix: String) async throws -> URL {
        URL(fileURLWithPath: "/tmp/\(prefix)\(UUID().uuidString)\(suffix)")
    }

    func attributesOfItem(atPath path: String) async throws -> [FileAttributeKey: Any] {
        let url = URL(fileURLWithPath: path).standardizedFileURL
        if let attrs = customAttributes[url] {
            return attrs
        }
        if let data = files[url] {
            return [
                .size: data.count,
                .type: FileAttributeType.typeRegular,
                .creationDate: Date(timeIntervalSince1970: 1),
                .modificationDate: Date(timeIntervalSince1970: 2)
            ]
        }
        if directories.contains(url) {
            return [
                .type: FileAttributeType.typeDirectory,
                .creationDate: Date(timeIntervalSince1970: 1),
                .modificationDate: Date(timeIntervalSince1970: 2)
            ]
        }
        throw ToolError.fileError(NSError(
            domain: "MockFileManager",
            code: 3,
            userInfo: [NSLocalizedDescriptionKey: "File not found: \(path)"]
        ))
    }

    func putFile(at url: URL, data: Data, attributes: [FileAttributeKey: Any]? = nil) async {
        let normalized = url.standardizedFileURL
        files[normalized] = data
        directories.insert(normalized.deletingLastPathComponent())
        if let attributes {
            customAttributes[normalized] = attributes
        }
    }

    func putDirectory(at url: URL, attributes: [FileAttributeKey: Any]? = nil) async {
        let normalized = url.standardizedFileURL
        directories.insert(normalized)
        directories.insert(normalized.deletingLastPathComponent())
        if let attributes {
            customAttributes[normalized] = attributes
        }
    }

    func data(at url: URL) async -> Data? {
        files[url.standardizedFileURL]
    }
}

actor MockCommandExecutor: CommandExecutor {
    struct Invocation: Sendable {
        let command: String
        let arguments: [String]
        let workingDirectory: URL
        let timeout: Int
    }

    struct Result: Sendable {
        let stdout: String
        let stderr: String
        let exitCode: Int
    }

    private var results: [String: Result] = [:]
    private var resolvedPaths: [String: String] = [:]
    private var timeoutCommands: Set<String> = []
    private var invocations: [Invocation] = []

    func execute(
        command: String,
        arguments: [String],
        workingDirectory: URL,
        environment: [String: String],
        timeout: Int
    ) async throws -> (stdout: String, stderr: String, exitCode: Int) {
        invocations.append(Invocation(
            command: command,
            arguments: arguments,
            workingDirectory: workingDirectory,
            timeout: timeout
        ))

        if timeoutCommands.contains(command) {
            throw ToolError.timeout
        }

        let key = Self.key(for: command, arguments: arguments)
        if let result = results[key] {
            return (result.stdout, result.stderr, result.exitCode)
        }

        return ("", "", 0)
    }

    func resolvePath(
        command: String,
        environment: [String: String],
        timeout: Int
    ) async throws -> String {
        resolvedPaths[command] ?? "/usr/bin/\(command)"
    }

    func setResult(command: String, arguments: [String] = [], result: Result) async {
        results[Self.key(for: command, arguments: arguments)] = result
    }

    func setResolvedPath(command: String, path: String) async {
        resolvedPaths[command] = path
    }

    func setTimeout(commandPath: String) async {
        timeoutCommands.insert(commandPath)
    }

    func lastInvocation() async -> Invocation? {
        invocations.last
    }

    private static func key(for command: String, arguments: [String]) -> String {
        command + " " + arguments.joined(separator: " ")
    }
}

struct MockServiceProvider: ToolServiceProvider {
    let fileManager: MockFileManager
    let commandExecutor: MockCommandExecutor

    // swiftlint:disable:next unavailable_function
    func getHTTPClient() async throws -> any ToolHTTPClient {
        fatalError("HTTP client is not used in these tests")
    }

    func getFileManager() async -> any ToolFileManager {
        fileManager
    }

    func getCommandExecutor() async -> any CommandExecutor {
        commandExecutor
    }

    func getConfig(key: String) async throws -> String? {
        nil
    }

    func getDeviantArtClient() async throws -> AKDeviantArtClient? {
        nil
    }

    func getPatreonClient() async throws -> AKPatreonClient? {
        nil
    }
}

actor MockStatusReporter: ToolStatusReporter {
    func report(status: ToolExecutionStatus) async throws {}
    func reportProgress(fractionCompleted: Double, message: String?) async throws {}
    func reportIntermediateResult(_ result: IntermediateResult) async throws {}
}

@MainActor
final class FileSystemToolSecurityTests: XCTestCase {
    private var sandbox: URL!
    private var context: ToolExecutionContext!
    private var fileManager: MockFileManager!
    private var commandExecutor: MockCommandExecutor!

    override func setUp() async throws {
        try await super.setUp()

        sandbox = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: sandbox, withIntermediateDirectories: true)

        fileManager = MockFileManager()
        commandExecutor = MockCommandExecutor()

        await fileManager.putDirectory(at: sandbox)

        context = ToolExecutionContext(
            executionId: UUID().uuidString,
            workingDirectory: sandbox,
            environment: [
                "PATH": "/usr/bin:/bin",
                "FOO": "bar"
            ],
            serviceProvider: MockServiceProvider(
                fileManager: fileManager,
                commandExecutor: commandExecutor
            ),
            statusReporter: MockStatusReporter()
        )
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: sandbox)
        sandbox = nil
        context = nil
        fileManager = nil
        commandExecutor = nil
        try await super.tearDown()
    }

    private func json(_ value: Any) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: value)
        // swiftlint:disable:next optional_data_string_conversion
        return String(decoding: data, as: UTF8.self)
    }

    private func decode<T: Decodable>(_ type: T.Type, from output: String) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(output.utf8))
    }

    private func assertToolThrows(
        _ tool: any AgentTool,
        input: String,
        containing expectedMessage: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await tool.execute(input: input, context: context)
            XCTFail("Expected error containing '\(expectedMessage)'", file: file, line: line)
        } catch {
            XCTAssertTrue(
                error.localizedDescription.localizedCaseInsensitiveContains(expectedMessage),
                "Expected '\(expectedMessage)' in '\(error.localizedDescription)'",
                file: file,
                line: line
            )
        }
    }

    func testReadFileReturnsUTF8Content() async throws {
        let file = sandbox.appendingPathComponent("hello.txt")
        await fileManager.putFile(at: file, data: Data("hello".utf8))

        let output = try await ReadFileTool().execute(
            input: try json(["path": file.path]),
            context: context
        )

        let response = try decode(ReadResponse.self, from: output)
        XCTAssertEqual(response.content, "hello")
        XCTAssertEqual(response.encoding, "utf8")
    }

    func testReadFileReturnsBase64Content() async throws {
        let file = sandbox.appendingPathComponent("payload.bin")
        let data = Data([0x00, 0xFF, 0x41])
        await fileManager.putFile(at: file, data: data)

        let output = try await ReadFileTool().execute(
            input: try json(["path": file.path, "encoding": "base64"]),
            context: context
        )

        let response = try decode(ReadResponse.self, from: output)
        XCTAssertEqual(response.content, data.base64EncodedString())
        XCTAssertEqual(response.encoding, "base64")
    }

    func testReadFileRejectsBinaryInUTF8Mode() async {
        let file = sandbox.appendingPathComponent("payload.bin")
        await fileManager.putFile(at: file, data: Data([0xFF, 0xD8, 0xFF]))

        await assertToolThrows(
            ReadFileTool(),
            input: try! json(["path": file.path]),
            containing: "base64"
        )
    }

    func testReadFileChunkReturnsRequestedSlice() async throws {
        let file = sandbox.appendingPathComponent("chunk.txt")
        await fileManager.putFile(at: file, data: Data("0123456789".utf8))

        let output = try await ReadFileChunkTool().execute(
            input: try json(["path": file.path, "offset": 2, "length": 4]),
            context: context
        )

        let response = try decode(ChunkResponse.self, from: output)
        XCTAssertEqual(response.content, "2345")
        XCTAssertEqual(response.offset, 2)
        XCTAssertEqual(response.length, 4)
    }

    func testReadFileChunkHandlesOffsetBeyondEndOfFile() async throws {
        let file = sandbox.appendingPathComponent("chunk.txt")
        await fileManager.putFile(at: file, data: Data("abc".utf8))

        let output = try await ReadFileChunkTool().execute(
            input: try json(["path": file.path, "offset": 10, "length": 5]),
            context: context
        )

        let response = try decode(ChunkResponse.self, from: output)
        XCTAssertEqual(response.content, "")
        XCTAssertEqual(response.length, 0)
    }

    func testReadFileChunkRejectsInvalidRange() async {
        await assertToolThrows(
            ReadFileChunkTool(),
            input: try! json(["path": sandbox.appendingPathComponent("missing.txt").path, "offset": -1, "length": 5]),
            containing: "non-negative"
        )
    }

    func testReadFilePathTraversalBlocked() async {
        await assertToolThrows(
            ReadFileTool(),
            input: try! json(["path": String(repeating: "../", count: 12) + "etc/passwd"]),
            containing: "working directory"
        )
    }

    func testProhibitedPathsAreRejected() async {
        for path in ["~/.ssh/id_rsa", "~/.env"] {
            await assertToolThrows(
                ReadFileTool(),
                input: try! json(["path": path]),
                containing: "prohibited"
            )
        }
    }

    func testCreateFileRejectsInvalidBase64() async {
        await assertToolThrows(
            CreateFileTool(),
            input: try! json(["path": sandbox.appendingPathComponent("invalid.bin").path, "content": "***", "encoding": "base64"]),
            containing: "base64"
        )
    }

    func testWriteFileAppendModeAppendsExistingContent() async throws {
        let file = sandbox.appendingPathComponent("append.txt")
        await fileManager.putFile(at: file, data: Data("hello ".utf8))

        _ = try await WriteFileTool().execute(
            input: try json(["path": file.path, "content": "world", "mode": "append"]),
            context: context
        )

        let contentsData = await fileManager.data(at: file)
        let contents = try XCTUnwrap(contentsData)
        XCTAssertEqual(String(data: contents, encoding: .utf8), "hello world")
    }

    func testWriteFileOutsideSandboxBlocked() async {
        await assertToolThrows(
            WriteFileTool(),
            input: try! json(["path": "/tmp/not-\(UUID().uuidString).txt", "content": "nope"]),
            containing: "working directory"
        )
    }

    func testMoveFileMovesContents() async throws {
        let source = sandbox.appendingPathComponent("source.txt")
        let destination = sandbox.appendingPathComponent("dest.txt")
        await fileManager.putFile(at: source, data: Data("content".utf8))

        _ = try await MoveFileTool().execute(
            input: try json(["source": source.path, "destination": destination.path]),
            context: context
        )

        let sourceData = await fileManager.data(at: source)
        let destinationRawData = await fileManager.data(at: destination)
        XCTAssertNil(sourceData)
        let destinationData = try XCTUnwrap(destinationRawData)
        XCTAssertEqual(String(data: destinationData, encoding: .utf8), "content")
    }

    func testCopyFilePreservesSource() async throws {
        let source = sandbox.appendingPathComponent("source.txt")
        let destination = sandbox.appendingPathComponent("dest.txt")
        await fileManager.putFile(at: source, data: Data("content".utf8))

        _ = try await CopyFileTool().execute(
            input: try json(["source": source.path, "destination": destination.path]),
            context: context
        )

        let sourceRawData = await fileManager.data(at: source)
        let destinationRawData = await fileManager.data(at: destination)
        let sourceData = try XCTUnwrap(sourceRawData)
        let destinationData = try XCTUnwrap(destinationRawData)
        XCTAssertEqual(String(data: sourceData, encoding: .utf8), "content")
        XCTAssertEqual(String(data: destinationData, encoding: .utf8), "content")
    }

    func testListDirectoryRecursiveIncludesNestedEntries() async throws {
        let rootFile = sandbox.appendingPathComponent("root.txt")
        let nestedDirectory = sandbox.appendingPathComponent("nested")
        let nestedFile = nestedDirectory.appendingPathComponent("child.txt")
        await fileManager.putFile(at: rootFile, data: Data())
        await fileManager.putDirectory(at: nestedDirectory)
        await fileManager.putFile(at: nestedFile, data: Data())

        let output = try await ListDirectoryTool().execute(
            input: try json(["path": sandbox.path, "recursive": true]),
            context: context
        )

        let response = try decode(EntriesResponse.self, from: output)
        XCTAssertGreaterThanOrEqual(response.totalCount, 3)
        XCTAssertTrue(response.entries.contains { $0.path == rootFile.path && !$0.isDirectory })
        XCTAssertTrue(response.entries.contains { $0.path == nestedDirectory.path && $0.isDirectory })
        XCTAssertTrue(response.entries.contains { $0.path == nestedFile.path && !$0.isDirectory })
    }

    func testSearchFilesHonorsRecursiveFlagAndAnchorsPattern() async throws {
        let rootSwift = sandbox.appendingPathComponent("one.swift")
        let suffixFile = sandbox.appendingPathComponent("one.swift.txt")
        let nestedDirectory = sandbox.appendingPathComponent("nested")
        let nestedSwift = nestedDirectory.appendingPathComponent("two.swift")
        await fileManager.putFile(at: rootSwift, data: Data())
        await fileManager.putFile(at: suffixFile, data: Data())
        await fileManager.putDirectory(at: nestedDirectory)
        await fileManager.putFile(at: nestedSwift, data: Data())

        let nonRecursiveOutput = try await SearchFilesTool().execute(
            input: try json(["directory": sandbox.path, "pattern": "*.swift", "recursive": false]),
            context: context
        )
        let recursiveOutput = try await SearchFilesTool().execute(
            input: try json(["directory": sandbox.path, "pattern": "*.swift", "recursive": true]),
            context: context
        )

        let nonRecursive = try decode(MatchesResponse.self, from: nonRecursiveOutput)
        let recursive = try decode(MatchesResponse.self, from: recursiveOutput)

        XCTAssertEqual(nonRecursive.matches, [rootSwift.path])
        XCTAssertEqual(Set(recursive.matches), Set([rootSwift.path, nestedSwift.path]))
    }

    func testCreateDirectoryWithoutIntermediateParentFails() async {
        let nested = sandbox.appendingPathComponent("missing/child")

        await assertToolThrows(
            CreateDirectoryTool(),
            input: try! json(["path": nested.path, "intermediate": false]),
            containing: "Parent directory does not exist"
        )
    }

    func testPathExistsReportsFileDirectoryAndMissingPath() async throws {
        let file = sandbox.appendingPathComponent("exists.txt")
        let directory = sandbox.appendingPathComponent("folder")
        let missing = sandbox.appendingPathComponent("missing.txt")
        await fileManager.putFile(at: file, data: Data("x".utf8))
        await fileManager.putDirectory(at: directory)

        let fileResponse = try decode(
            ExistsResponse.self,
            from: try await PathExistsTool().execute(input: try json(["path": file.path]), context: context)
        )
        let directoryResponse = try decode(
            ExistsResponse.self,
            from: try await PathExistsTool().execute(input: try json(["path": directory.path]), context: context)
        )
        let missingResponse = try decode(
            ExistsResponse.self,
            from: try await PathExistsTool().execute(input: try json(["path": missing.path]), context: context)
        )

        XCTAssertTrue(fileResponse.exists)
        XCTAssertEqual(fileResponse.type, "file")
        XCTAssertTrue(directoryResponse.exists)
        XCTAssertEqual(directoryResponse.type, "directory")
        XCTAssertFalse(missingResponse.exists)
        XCTAssertEqual(missingResponse.type, "none")
    }

    func testGetFileInfoReturnsSizeDatesAndDirectoryFlag() async throws {
        let file = sandbox.appendingPathComponent("info.txt")
        await fileManager.putFile(at: file, data: Data("content".utf8))

        let output = try await GetFileInfoTool().execute(
            input: try json(["path": file.path]),
            context: context
        )

        let response = try decode(FileInfoResponse.self, from: output)
        XCTAssertEqual(response.size, 7)
        XCTAssertFalse(response.isDirectory)
        XCTAssertFalse(response.created.isEmpty)
        XCTAssertFalse(response.modified.isEmpty)
    }

    func testDeleteFileRemovesFile() async throws {
        let file = sandbox.appendingPathComponent("delete.txt")
        await fileManager.putFile(at: file, data: Data("content".utf8))

        _ = try await DeleteFileTool().execute(
            input: try json(["path": file.path]),
            context: context
        )

        let fileData = await fileManager.data(at: file)
        XCTAssertNil(fileData)
    }

    func testDeleteDirectoryRemovesDescendants() async throws {
        let directory = sandbox.appendingPathComponent("delete-dir")
        let file = directory.appendingPathComponent("child.txt")
        await fileManager.putDirectory(at: directory)
        await fileManager.putFile(at: file, data: Data("content".utf8))

        _ = try await DeleteDirectoryTool().execute(
            input: try json(["path": directory.path]),
            context: context
        )

        let exists = await fileManager.exists(at: directory)
        XCTAssertFalse(exists)
        let fileData = await fileManager.data(at: file)
        XCTAssertNil(fileData)
    }

    func testRunCommandExecutesSafeCommandWithResolvedPath() async throws {
        await commandExecutor.setResolvedPath(command: "echo", path: "/bin/echo")
        await commandExecutor.setResult(
            command: "/bin/echo",
            arguments: ["hello", "world"],
            result: .init(stdout: "hello world", stderr: "", exitCode: 0)
        )

        let output = try await RunCommandTool().execute(
            input: try json(["command": "echo hello world", "cwd": sandbox.path, "timeout": 12]),
            context: context
        )

        let response = try decode(CommandResponse.self, from: output)
        let invocation = await commandExecutor.lastInvocation()

        XCTAssertEqual(response.stdout, "hello world")
        XCTAssertEqual(response.exitCode, 0)
        XCTAssertEqual(invocation?.command, "/bin/echo")
        XCTAssertEqual(invocation?.arguments, ["hello", "world"])
        XCTAssertEqual(invocation?.workingDirectory.standardizedFileURL, sandbox.standardizedFileURL)
        XCTAssertEqual(invocation?.timeout, 12)
    }

    func testRunCommandRejectsNetworkCommands() async {
        await assertToolThrows(
            RunCommandTool(),
            input: try! json(["command": "curl https://example.com"]),
            containing: "not allowed"
        )
    }

    func testRunCommandRejectsShellMetacharacters() async {
        await assertToolThrows(
            RunCommandTool(),
            input: try! json(["command": "ls | cat"]),
            containing: "unsafe character"
        )
    }

    func testRunCommandRejectsUnknownCommand() async {
        await assertToolThrows(
            RunCommandTool(),
            input: try! json(["command": "python --version"]),
            containing: "allowed list"
        )
    }

    func testRunCommandPropagatesTimeout() async {
        await commandExecutor.setResolvedPath(command: "ls", path: "/bin/ls")
        await commandExecutor.setTimeout(commandPath: "/bin/ls")

        await assertToolThrows(
            RunCommandTool(),
            input: try! json(["command": "ls"]),
            containing: "timed out"
        )
    }

    func testGetEnvironmentReturnsSpecificKey() async throws {
        let output = try await GetEnvironmentTool().execute(
            input: try json(["key": "FOO"]),
            context: context
        )

        let response = try decode(EnvironmentValueResponse.self, from: output)
        XCTAssertEqual(response.value, "bar")
    }

    func testGetEnvironmentReturnsAllVariables() async throws {
        let output = try await GetEnvironmentTool().execute(
            input: "{}",
            context: context
        )

        let response = try decode(EnvironmentMapResponse.self, from: output)
        XCTAssertEqual(response.variables["FOO"], "bar")
        XCTAssertNotNil(response.variables["PATH"])
    }

    func testGetWorkingDirectoryReturnsSandbox() async throws {
        let output = try await GetWorkingDirectoryTool().execute(
            input: "{}",
            context: context
        )

        let response = try decode(WorkingDirectoryResponse.self, from: output)
        XCTAssertEqual(response.path, sandbox.path)
    }
}

// swiftlint:enable force_try
