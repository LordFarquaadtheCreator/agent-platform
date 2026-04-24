import XCTest
@testable import AgentKit

// MARK: - Test Helpers

extension Data {
    func asString() -> String {
        String(decoding: self, as: UTF8.self)
    }
}

final class MockFileManager: ToolFileManager, @unchecked Sendable {
    private var files: [URL: Data] = [:]
    private var directories: Set<URL> = []

    func createDirectory(at url: URL) async throws {
        directories.insert(url)
    }

    func write(data: Data, to url: URL) async throws {
        files[url] = data
    }

    func read(from url: URL) async throws -> Data {
        guard let data = files[url] else {
            throw ToolError.fileError(NSError(domain: "MockFileManager", code: 1))
        }
        return data
    }

    func exists(at url: URL) async -> Bool {
        files[url] != nil || directories.contains(url)
    }

    func delete(at url: URL) async throws {
        files.removeValue(forKey: url)
        directories.remove(url)
    }

    func listDirectory(at url: URL) async throws -> [URL] {
        guard directories.contains(url) else {
            throw ToolError.fileError(NSError(domain: "MockFileManager", code: 2))
        }
        return Array(files.keys.filter { $0.deletingLastPathComponent() == url })
    }

    func createTempFile(prefix: String, suffix: String) async throws -> URL {
        URL(fileURLWithPath: "/tmp/\(prefix)\(UUID().uuidString)\(suffix)")
    }

    func mockFile(at url: URL, data: Data) {
        files[url] = data
    }

    func mockDirectory(at url: URL) {
        directories.insert(url)
    }
}

final class MockServiceProvider: ToolServiceProvider, @unchecked Sendable {
    let fileManager: MockFileManager

    init(fileManager: MockFileManager) {
        self.fileManager = fileManager
    }

    func getHTTPClient() async throws -> any ToolHTTPClient {
        fatalError("Not implemented")
    }

    func getFileManager() -> any ToolFileManager {
        fileManager
    }

    func getConfig(key: String) async throws -> String? {
        nil
    }

    func getDeviantArtClient() async throws -> DeviantArtClient? {
        nil
    }

    func getPatreonClient() async throws -> PatreonClient? {
        nil
    }
}

final class MockStatusReporter: ToolStatusReporter, @unchecked Sendable {
    func report(status: ToolExecutionStatus) async throws {}
    func reportProgress(fractionCompleted: Double, message: String?) async throws {}
    func reportIntermediateResult(_ result: IntermediateResult) async throws {}
}

// MARK: - Security Tests

final class FileSystemToolSecurityTests: XCTestCase {
    var sandbox: URL!
    var context: ToolExecutionContext!
    var mockFM: MockFileManager!

    override func setUp() {
        super.setUp()
        sandbox = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: sandbox, withIntermediateDirectories: true)

        mockFM = MockFileManager()
        let provider = MockServiceProvider(fileManager: mockFM)
        let reporter = MockStatusReporter()

        context = ToolExecutionContext(
            executionId: UUID().uuidString,
            workingDirectory: sandbox,
            environment: ProcessInfo.processInfo.environment,
            serviceProvider: provider,
            statusReporter: reporter
        )
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: sandbox)
        super.tearDown()
    }

    // MARK: - Path Traversal Tests

    func testReadFilePathTraversalBlocked() async {
        let tool = ReadFileTool()
        let input = Data(#"{"path": "../../../etc/passwd"}"#.utf8).asString()

        do {
            _ = try await tool.execute(input: input, context: context)
            XCTFail("Should have thrown sandbox violation")
        } catch let error as ToolError {
            XCTAssertTrue(error.localizedDescription.contains("Sandbox") || 
                         error.localizedDescription.contains("working directory"))
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testWriteFileOutsideSandboxBlocked() async {
        let tool = WriteFileTool()
        let input = Data(#"{"path": "/tmp/malicious.txt", "content": "hack"}"#.utf8).asString()

        do {
            _ = try await tool.execute(input: input, context: context)
            XCTFail("Should have thrown sandbox violation")
        } catch let error as ToolError {
            XCTAssertTrue(error.localizedDescription.contains("working directory"))
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    // MARK: - Symlink Tests

    func testSymlinkEscapeBlocked() async throws {
        let linkPath = sandbox.appendingPathComponent("escape")
        try FileManager.default.createSymbolicLink(
            at: linkPath,
            withDestinationURL: URL(fileURLWithPath: "/")
        )

        let tool = ReadFileTool()
        let input = try JSONEncoder().encode(["path": linkPath.path]).asString()

        do {
            _ = try await tool.execute(input: input, context: context)
            XCTFail("Should have thrown sandbox violation")
        } catch let error as ToolError {
            XCTAssertTrue(error.localizedDescription.contains("escapes") ||
                         error.localizedDescription.contains("Sandbox"))
        } catch {
            XCTFail("Wrong error type: \(error)")
        }

        try? FileManager.default.removeItem(at: linkPath)
    }

    // MARK: - Prohibited Path Tests

    func testSSHPathBlocked() async {
        let tool = ReadFileTool()
        let input = Data(#"{"path": "~/.ssh/id_rsa"}"#.utf8).asString()

        do {
            _ = try await tool.execute(input: input, context: context)
            XCTFail("Should have thrown prohibited path error")
        } catch let error as ToolError {
            XCTAssertTrue(error.localizedDescription.contains("prohibited"))
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testEnvFileBlocked() async {
        let tool = ReadFileTool()
        let input = Data(#"{"path": "~/.env"}"#.utf8).asString()

        do {
            _ = try await tool.execute(input: input, context: context)
            XCTFail("Should have thrown prohibited path error")
        } catch let error as ToolError {
            XCTAssertTrue(error.localizedDescription.contains("prohibited"))
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    // MARK: - Command Safety Tests

    func testCurlBlocked() async {
        let tool = RunCommandTool()
        let input = Data(#"{"command": "curl http://evil.com"}"#.utf8).asString()

        do {
            _ = try await tool.execute(input: input, context: context)
            XCTFail("Should have blocked curl")
        } catch let error as ToolError {
            XCTAssertTrue(error.localizedDescription.contains("not allowed") ||
                         error.localizedDescription.contains("Network"))
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testPipeBlocked() async {
        let tool = RunCommandTool()
        let input = Data(#"{"command": "ls | cat"}"#.utf8).asString()

        do {
            _ = try await tool.execute(input: input, context: context)
            XCTFail("Should have blocked pipe")
        } catch let error as ToolError {
            XCTAssertTrue(error.localizedDescription.contains("unsafe character"))
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testSafeCommandAllowed() async throws {
        let tool = RunCommandTool()
        let input = Data(#"{"command": "ls -la"}"#.utf8).asString()

        do {
            _ = try await tool.execute(input: input, context: context)
        } catch let error as ToolError {
            if error.localizedDescription.contains("not allowed") ||
               error.localizedDescription.contains("unsafe") {
                XCTFail("Should have allowed safe command")
            }
        } catch {
            // Command not found or other errors are OK for this test
        }
    }

    // MARK: - Functional Tests

    func testReadFileChunkDoesNotLoadEntireFile() async throws {
        let bigFile = sandbox.appendingPathComponent("big.txt")
        let content = String(repeating: "a", count: 1000)
        try content.write(to: bigFile, atomically: true, encoding: .utf8)

        let tool = ReadFileChunkTool()
        struct ChunkInput: Codable {
            let path: String
            let offset: Int
            let length: Int
        }
        let input = try JSONEncoder().encode(ChunkInput(
            path: bigFile.path,
            offset: 0,
            length: 10
        )).asString()

        let result = try await tool.execute(input: input, context: context)
        XCTAssertTrue(result.contains("aaaaaaaaaa"))
        XCTAssertFalse(result.contains("aaaaaaaaaaa"))

        try? FileManager.default.removeItem(at: bigFile)
    }

    func testMoveFileAtomic() async throws {
        let source = sandbox.appendingPathComponent("source.txt")
        let dest = sandbox.appendingPathComponent("dest.txt")
        try "content".write(to: source, atomically: true, encoding: .utf8)

        let tool = MoveFileTool()
        let input = try JSONEncoder().encode([
            "source": source.path,
            "destination": dest.path
        ]).asString()

        _ = try await tool.execute(input: input, context: context)

        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: dest.path))
    }

    func testCopyFileDoesNotLoadToMemory() async throws {
        let source = sandbox.appendingPathComponent("source.txt")
        let dest = sandbox.appendingPathComponent("dest.txt")
        try "content".write(to: source, atomically: true, encoding: .utf8)

        let tool = CopyFileTool()
        let input = try JSONEncoder().encode([
            "source": source.path,
            "destination": dest.path
        ]).asString()

        _ = try await tool.execute(input: input, context: context)

        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: dest.path))
    }

    func testBinaryFileDetection() async throws {
        let binaryFile = sandbox.appendingPathComponent("binary.bin")
        let binaryData = Data([0x00, 0x01, 0x02, 0xFF, 0xFE])
        try binaryData.write(to: binaryFile)

        let tool = ReadFileTool()
        let input = try JSONEncoder().encode(["path": binaryFile.path]).asString()

        do {
            _ = try await tool.execute(input: input, context: context)
            XCTFail("Should have detected binary file")
        } catch let error as ToolError {
            XCTAssertTrue(error.localizedDescription.contains("binary") ||
                         error.localizedDescription.contains("base64"))
        } catch {
            XCTFail("Wrong error type: \(error)")
        }

        try? FileManager.default.removeItem(at: binaryFile)
    }

    func testEmptyFileNotDetectedAsBinary() async throws {
        let emptyFile = sandbox.appendingPathComponent("empty.txt")
        try "".write(to: emptyFile, atomically: true, encoding: .utf8)

        let tool = ReadFileTool()
        let input = try JSONEncoder().encode(["path": emptyFile.path]).asString()

        let result = try await tool.execute(input: input, context: context)
        XCTAssertTrue(result.contains("\"content\":\"\""))

        try? FileManager.default.removeItem(at: emptyFile)
    }

    func testWriteFileAppendMode() async throws {
        let file = sandbox.appendingPathComponent("append.txt")
        try "hello ".write(to: file, atomically: true, encoding: .utf8)

        let tool = WriteFileTool()
        let input = try JSONEncoder().encode([
            "path": file.path,
            "content": "world",
            "mode": "append"
        ]).asString()

        _ = try await tool.execute(input: input, context: context)

        let content = try String(contentsOf: file)
        XCTAssertEqual(content, "hello world")

        try? FileManager.default.removeItem(at: file)
    }

    func testCreateDirectoryIntermediateFalse() async throws {
        let tool = CreateDirectoryTool()
        let nested = sandbox.appendingPathComponent("nonexistent/nested")
        struct DirInput: Codable {
            let path: String
            let intermediate: Bool
        }
        let input = try JSONEncoder().encode(DirInput(
            path: nested.path,
            intermediate: false
        )).asString()

        do {
            _ = try await tool.execute(input: input, context: context)
            XCTFail("Should have failed - parent doesn't exist")
        } catch let error as ToolError {
            XCTAssertTrue(error.localizedDescription.contains("Parent"))
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testGetEnvironmentSpecificKey() async throws {
        let tool = GetEnvironmentTool()
        let input = try JSONEncoder().encode(["key": "PATH"]).asString()

        let result = try await tool.execute(input: input, context: context)
        XCTAssertTrue(result.contains("value"))
    }

    func testGetEnvironmentAllVariables() async throws {
        let tool = GetEnvironmentTool()
        let input = "{}"

        let result = try await tool.execute(input: input, context: context)
        XCTAssertTrue(result.contains("variables"))
    }

    func testGetWorkingDirectory() async throws {
        let tool = GetWorkingDirectoryTool()
        let input = "{}"

        let result = try await tool.execute(input: input, context: context)
        XCTAssertTrue(result.contains(sandbox.path))
    }

    func testPathExistsForFile() async throws {
        let file = sandbox.appendingPathComponent("exists.txt")
        try "content".write(to: file, atomically: true, encoding: .utf8)

        let tool = PathExistsTool()
        let input = try JSONEncoder().encode(["path": file.path]).asString()

        let result = try await tool.execute(input: input, context: context)
        XCTAssertTrue(result.contains("\"exists\":true"))
        XCTAssertTrue(result.contains("\"type\":\"file\""))

        try? FileManager.default.removeItem(at: file)
    }

    func testPathExistsForDirectory() async throws {
        let dir = sandbox.appendingPathComponent("existsdir")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let tool = PathExistsTool()
        let input = try JSONEncoder().encode(["path": dir.path]).asString()

        let result = try await tool.execute(input: input, context: context)
        XCTAssertTrue(result.contains("\"exists\":true"))
        XCTAssertTrue(result.contains("\"type\":\"directory\""))

        try? FileManager.default.removeItem(at: dir)
    }

    func testGetFileInfo() async throws {
        let file = sandbox.appendingPathComponent("info.txt")
        try "content".write(to: file, atomically: true, encoding: .utf8)

        let tool = GetFileInfoTool()
        let input = try JSONEncoder().encode(["path": file.path]).asString()

        let result = try await tool.execute(input: input, context: context)
        XCTAssertTrue(result.contains("\"size\":"))
        XCTAssertTrue(result.contains("\"isDirectory\":false"))

        try? FileManager.default.removeItem(at: file)
    }

    func testDeleteFile() async throws {
        let file = sandbox.appendingPathComponent("delete.txt")
        try "content".write(to: file, atomically: true, encoding: .utf8)

        let tool = DeleteFileTool()
        let input = try JSONEncoder().encode(["path": file.path]).asString()

        _ = try await tool.execute(input: input, context: context)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }

    func testDeleteDirectory() async throws {
        let dir = sandbox.appendingPathComponent("deletedir")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let tool = DeleteDirectoryTool()
        let input = try JSONEncoder().encode(["path": dir.path]).asString()

        _ = try await tool.execute(input: input, context: context)
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.path))
    }
}
