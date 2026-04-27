import Foundation

/// Actor for thread-safe process management
private actor ProcessRegistry {
    var processes: [Int: Process] = [:]

    func register(pid: Int, process: Process) {
        processes[pid] = process
    }

    func get(pid: Int) -> Process? {
        processes[pid]
    }

    func remove(pid: Int) {
        processes.removeValue(forKey: pid)
    }

    func allPIDs() -> [Int] {
        Array(processes.keys)
    }

    func isRunning(pid: Int) -> Bool {
        processes[pid]?.isRunning ?? false
    }
}

/// Manages local worker processes for task execution
public final class WorkerProcessManager {
    private let logger = AppLogger.worker
    private let fileManager = FileManager.default
    private let logsDirectory: URL
    private let processRegistry = ProcessRegistry()

    public init() throws {
        // Create logs directory
        let appSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let appFolder = appSupport.appendingPathComponent("SenorPlatform", isDirectory: true)
        logsDirectory = appFolder.appendingPathComponent("logs", isDirectory: true)

        if !fileManager.fileExists(atPath: logsDirectory.path) {
            try fileManager.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
        }
    }

    public func startup() async throws {
        // Clean up any stale log files older than 7 days
        cleanupStaleLogs()
        logger.info("WorkerProcessManager started")
    }

    public func shutdown() async throws {
        // Terminate all active processes
        let pids = await getActivePIDs()
        for pid in pids {
            await terminate(pid: pid, force: true)
        }
        logger.info("WorkerProcessManager shutdown complete")
    }

    // MARK: - Process Lifecycle

    /// Spawn a new worker process
    public func spawn(
        scriptPath: String,
        arguments: [String],
        environment: [String: String]? = nil,
        taskRunId: String
    ) async throws -> ProcessResult {
        guard fileManager.isExecutableFile(atPath: scriptPath) else {
            throw AppError.workerSpawnFailed(
                NSError(domain: "WorkerProcessManager", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Script not executable: \(scriptPath)"
                ])
            )
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: scriptPath)
        process.arguments = arguments

        // Set up environment
        var env = ProcessInfo.processInfo.environment
        env["TASK_RUN_ID"] = taskRunId
        env["SENOR_PLATFORM"] = "1"
        if let customEnv = environment {
            env.merge(customEnv) { _, new in new }
        }
        process.environment = env

        // Create log files
        let (stdoutPath, stderrPath) = createLogFiles(taskRunId: taskRunId)
        guard let stdoutHandle = FileHandle(forWritingAtPath: stdoutPath),
              let stderrHandle = FileHandle(forWritingAtPath: stderrPath) else {
            throw AppError.workerSpawnFailed(NSError(domain: "WorkerProcessManager", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to create log file handles at paths: \(stdoutPath), \(stderrPath)"
            ]))
        }
        process.standardOutput = stdoutHandle
        process.standardError = stderrHandle

        // Start process
        try process.run()
        let pid = Int(process.processIdentifier)

        // Register in active processes
        await processRegistry.register(pid: pid, process: process)

        logger.info("Spawned worker process: PID \(pid) for task run \(taskRunId)")

        return ProcessResult(
            pid: pid,
            stdoutPath: stdoutPath,
            stderrPath: stderrPath
        )
    }

    /// Wait for process completion
    public func wait(for pid: Int) async -> ProcessExit {
        guard let process = await processRegistry.get(pid: pid) else {
            return ProcessExit(pid: pid, exitCode: -1, error: "Process not found")
        }

        // Wait for termination in a separate task to avoid blocking actor
        let exitCode = await Task.detached {
            process.waitUntilExit()
            return Int(process.terminationStatus)
        }.value

        // Unregister
        await processRegistry.remove(pid: pid)

        return ProcessExit(pid: pid, exitCode: exitCode, error: nil)
    }

    /// Terminate a process (graceful then force)
    public func terminate(pid: Int, force: Bool = false) async {
        guard let process = await processRegistry.get(pid: pid) else {
            return
        }

        if force {
            process.terminate()
            logger.info("Force terminated process: PID \(pid)")
        } else {
            // Send SIGTERM for graceful shutdown
            let result = kill(pid_t(pid), SIGTERM)
            if result == 0 {
                logger.info("Sent SIGTERM to process: PID \(pid)")
            } else {
                logger.warning("Failed to send SIGTERM to PID \(pid): errno \(errno)")
            }

            // Wait 5 seconds then force kill if still running
            try? await Task.sleep(nanoseconds: 5_000_000_000)

            if process.isRunning {
                process.terminate()
                logger.info("Force terminated after timeout: PID \(pid)")
            }
        }

        // Unregister
        await processRegistry.remove(pid: pid)
    }

    /// Restart a process (kill and respawn)
    public func restart(
        pid: Int,
        scriptPath: String,
        arguments: [String],
        environment: [String: String]? = nil,
        taskRunId: String
    ) async throws -> ProcessResult {
        await terminate(pid: pid, force: true)
        // Small delay to ensure cleanup
        try? await Task.sleep(nanoseconds: 100_000_000)
        return try await spawn(
            scriptPath: scriptPath,
            arguments: arguments,
            environment: environment,
            taskRunId: taskRunId
        )
    }

    /// Check if a process is still running
    public func isRunning(pid: Int) async -> Bool {
        await processRegistry.isRunning(pid: pid)
    }

    /// Get all active PIDs
    public func getActivePIDs() async -> [Int] {
        await processRegistry.allPIDs()
    }

    /// Reconcile orphaned PIDs on app relaunch
    public func reconcileOrphanedPIDs(
        recordedPIDs: [Int],
        taskRunRepository: TaskRunRepository
    ) async throws {
        for pid in recordedPIDs {
            // Check if process actually exists
            if kill(pid_t(pid), 0) == -1 {
                // Process doesn't exist - mark as terminated
                logger.info("Reconciling orphaned PID: \(pid) (process not found)")
            } else {
                // Process exists but we don't own it - attempt to terminate
                logger.warning("Found orphaned running process: PID \(pid), terminating")
                kill(pid_t(pid), SIGTERM)
            }
        }
    }

    // MARK: - Private Methods

    private func createLogFiles(taskRunId: String) -> (stdout: String, stderr: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let baseName = "\(taskRunId)_\(timestamp)"

        let stdoutPath = logsDirectory
            .appendingPathComponent("\(baseName)_stdout.log")
            .path
        let stderrPath = logsDirectory
            .appendingPathComponent("\(baseName)_stderr.log")
            .path

        // Create empty files
        fileManager.createFile(atPath: stdoutPath, contents: nil, attributes: nil)
        fileManager.createFile(atPath: stderrPath, contents: nil, attributes: nil)

        return (stdoutPath, stderrPath)
    }

    private func cleanupStaleLogs() {
        let cutoffDate = Date().addingTimeInterval(-7 * 24 * 60 * 60) // 7 days ago

        do {
            let files = try fileManager.contentsOfDirectory(at: logsDirectory, includingPropertiesForKeys: [.creationDateKey])
            for file in files {
                if let attrs = try? fileManager.attributesOfItem(atPath: file.path),
                   let date = attrs[.creationDate] as? Date,
                   date < cutoffDate {
                    try? fileManager.removeItem(at: file)
                }
            }
        } catch {
            logger.error("Failed to cleanup stale logs: \(error)")
        }
    }
}

// MARK: - Result Types

public struct ProcessResult: Sendable {
    public let pid: Int
    public let stdoutPath: String
    public let stderrPath: String

    public init(pid: Int, stdoutPath: String, stderrPath: String) {
        self.pid = pid
        self.stdoutPath = stdoutPath
        self.stderrPath = stderrPath
    }
}

public struct ProcessExit: Sendable {
    public let pid: Int
    public let exitCode: Int
    public let error: String?
    public let isSuccess: Bool

    public init(pid: Int, exitCode: Int, error: String?) {
        self.pid = pid
        self.exitCode = exitCode
        self.error = error
        self.isSuccess = exitCode == 0
    }
}
