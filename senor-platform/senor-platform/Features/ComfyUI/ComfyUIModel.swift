import Foundation
import Combine

@MainActor
public final class ComfyUIViewModel: ObservableObject {
    // MARK: - Published State

    @Published public private(set) var workflows: [ComfyUIWorkflow] = []
    @Published public private(set) var executions: [ComfyUIExecution] = []
    @Published public private(set) var queueStatus = ComfyUIQueueStatus()
    @Published public private(set) var isConnected = false
    @Published public private(set) var isLoading = false
    @Published public private(set) var isRefreshing = false
    @Published public private(set) var errorMessage: String?
    @Published public var selectedWorkflow: ComfyUIWorkflow?
    @Published public var selectedExecution: ComfyUIExecution?

    // MARK: - Services

    private let client: ComfyUIClient
    private let executionRepository: ComfyUIExecutionRepository
    private let settingsService: SettingsService
    private let connectivityService: ConnectivityService?
    private var cancellables = Set<AnyCancellable>()
    private var objectInfo: [String: ComfyUIObjectInfoNode] = [:]
    private var hasLoaded = false

    public var isOffline: Bool {
        connectivityService?.isOnline == false
    }

    init(
        client: ComfyUIClient,
        executionRepository: ComfyUIExecutionRepository,
        settingsService: SettingsService,
        connectivityService: ConnectivityService? = nil
    ) {
        self.client = client
        self.executionRepository = executionRepository
        self.settingsService = settingsService
        self.connectivityService = connectivityService
    }

    // MARK: - Load

    func load() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        await refresh()
    }

    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        await checkConnection()
        await loadWorkflows()
        await loadExecutions()
        await refreshQueue()

        if isConnected {
            await connectWebSocket()
        }
    }

    // MARK: - Connection

    private func checkConnection() async {
        isConnected = await client.isReachable()
    }

    // MARK: - Workflows

    private func loadWorkflows() async {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let defaultPath = home.appendingPathComponent("Documents/ComfyUI/user/default/workflows")
        let settings = settingsService.loadComfyUISettings()
        let workflowDir = URL(fileURLWithPath: settings.serverURL.isEmpty
            ? defaultPath.path
            : defaultPath.path)

        guard FileManager.default.fileExists(atPath: workflowDir.path) else {
            workflows = []
            return
        }

        do {
            let files = try FileManager.default.contentsOfDirectory(at: workflowDir, includingPropertiesForKeys: nil)
            let jsonFiles = files.filter { $0.pathExtension == "json" }

            var parsed: [ComfyUIWorkflow] = []
            for file in jsonFiles.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                if let workflow = try? parseWorkflow(at: file) {
                    parsed.append(workflow)
                }
            }
            workflows = parsed
        } catch {
            errorMessage = "Failed to load workflows: \(error.localizedDescription)"
        }
    }

    private func parseWorkflow(at url: URL) throws -> ComfyUIWorkflow {
        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]

        var nodes: [ComfyUINode] = []
        for (nodeID, nodeData) in json {
            guard let nodeDict = nodeData as? [String: Any],
                  let classType = nodeDict["class_type"] as? String else { continue }

            // Skip subgraphs / groups at surface level
            let isSubgraph = classType.hasPrefix("Workflow") || classType.hasPrefix("Group")
            if isSubgraph { continue }

            var inputs: [ComfyUIInputParameter] = []
            if let inputDict = nodeDict["inputs"] as? [String: Any] {
                for (key, value) in inputDict {
                    let param = parseInputParameter(key: key, value: value, nodeClass: classType)
                    inputs.append(param)
                }
            }

            nodes.append(ComfyUINode(
                id: nodeID,
                classType: classType,
                inputs: inputs
            ))
        }

        return ComfyUIWorkflow(
            id: url.lastPathComponent,
            name: url.deletingPathExtension().lastPathComponent,
            path: url.path,
            nodes: nodes
        )
    }

    private func parseInputParameter(key: String, value: Any, nodeClass: String) -> ComfyUIInputParameter {
        let id = "\(nodeClass).\(key)"
        let defaultValue: String
        let type: ComfyUIInputType

        switch value {
        case let str as String:
            defaultValue = str
            type = (key.contains("image") || key.contains("file")) ? .image : .string
        case let int as Int:
            defaultValue = String(int)
            type = .int
        case let double as Double:
            defaultValue = String(double)
            type = .float
        case let bool as Bool:
            defaultValue = bool ? "true" : "false"
            type = .boolean
        case is [Any]:
            // Array values are typically connections; skip or treat as string
            defaultValue = ""
            type = .string
        default:
            defaultValue = ""
            type = .string
        }

        return ComfyUIInputParameter(
            id: id,
            key: key,
            type: type,
            defaultValue: defaultValue,
            currentValue: defaultValue
        )
    }

    // MARK: - Execution

    private func loadExecutions() async {
        do {
            let records = try await executionRepository.listRecent(limit: 50)
            executions = records.map { record in
                let paths = (try? JSONSerialization.jsonObject(with: record.outputPathsJson.data(using: .utf8)!) as? [String]) ?? []
                return ComfyUIExecution(
                    id: record.id,
                    workflowID: record.workflowID,
                    workflowName: record.workflowName,
                    status: ComfyUIExecutionStatus(rawValue: record.status) ?? .error,
                    progress: record.progress,
                    currentNode: record.currentNode,
                    startedAt: record.startedAt,
                    completedAt: record.completedAt,
                    outputs: paths,
                    outputDirectory: record.outputDirectory,
                    errorMessage: record.errorMessage
                )
            }
        } catch {
            AppLogger.api.error("Failed to load executions: \(error)")
        }
    }

    func executeWorkflow(workflow: ComfyUIWorkflow, outputDirectory: String? = nil) async {
        guard isConnected else {
            errorMessage = "ComfyUI server not connected"
            return
        }

        // Build workflow JSON from current input values
        guard let workflowJSON = try? buildWorkflowJSON(workflow: workflow) else {
            errorMessage = "Failed to build workflow JSON"
            return
        }

        do {
            let response = try await client.queuePrompt(workflowJSON: workflowJSON)

            let outputDir = outputDirectory ?? defaultOutputDirectory()
            let inputsJSON = try JSONSerialization.data(withJSONObject: workflowJSON)
            let inputsString = String(data: inputsJSON, encoding: .utf8) ?? "{}"

            let record = ComfyUIExecutionRecord(
                id: response.promptID,
                workflowID: workflow.id,
                workflowName: workflow.name,
                inputsJson: inputsString,
                status: ComfyUIExecutionStatus.queued.rawValue,
                outputDirectory: outputDir
            )
            _ = try await executionRepository.create(execution: record)

            // Add to local executions
            let execution = ComfyUIExecution(
                id: response.promptID,
                workflowID: workflow.id,
                workflowName: workflow.name,
                status: .queued,
                outputDirectory: outputDir
            )
            executions.insert(execution, at: 0)

            await refreshQueue()
        } catch {
            errorMessage = "Execution failed: \(error.localizedDescription)"
        }
    }

    private func buildWorkflowJSON(workflow: ComfyUIWorkflow) throws -> [String: Any] {
        var result: [String: Any] = [:]
        for node in workflow.nodes {
            var inputs: [String: Any] = [:]
            for param in node.inputs {
                switch param.type {
                case .int:
                    inputs[param.key] = Int(param.currentValue) ?? Int(param.defaultValue) ?? 0
                case .float:
                    inputs[param.key] = Double(param.currentValue) ?? Double(param.defaultValue) ?? 0.0
                case .boolean:
                    inputs[param.key] = param.currentValue.lowercased() == "true"
                default:
                    inputs[param.key] = param.currentValue.isEmpty ? param.defaultValue : param.currentValue
                }
            }
            result[node.id] = [
                "inputs": inputs,
                "class_type": node.classType
            ]
        }
        return result
    }

    private func defaultOutputDirectory() -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Documents/ComfyUI/user/default/output").path
    }

    func cancelExecution(id: String) async {
        do {
            try await client.interrupt()
            if let execution = executions.first(where: { $0.id == id }) {
                // Update record
                if let record = try? await executionRepository.getById(id: id) {
                    var updated = record
                    updated.status = ComfyUIExecutionStatus.cancelled.rawValue
                    updated.completedAt = Date()
                    _ = try? await executionRepository.update(execution: updated)
                }
                // Update local
                if let idx = executions.firstIndex(where: { $0.id == id }) {
                    executions[idx] = ComfyUIExecution(
                        id: execution.id,
                        workflowID: execution.workflowID,
                        workflowName: execution.workflowName,
                        status: .cancelled,
                        progress: execution.progress,
                        currentNode: execution.currentNode,
                        startedAt: execution.startedAt,
                        completedAt: Date(),
                        outputs: execution.outputs,
                        outputDirectory: execution.outputDirectory
                    )
                }
            }
        } catch {
            errorMessage = "Cancel failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Queue

    func refreshQueue() async {
        guard isConnected else { return }
        do {
            let queue = try await client.getQueue()
            // Parse queue_running and queue_pending
            var running: ComfyUIQueueItem?
            var pending: [ComfyUIQueueItem] = []

            if let first = queue.queueRunning.first,
               let promptID = first["prompt_id"]?.stringValue,
               let number = first["number"]?.intValue {
                running = ComfyUIQueueItem(id: promptID, promptID: promptID, number: number)
            }

            for item in queue.queuePending {
                if let promptID = item["prompt_id"]?.stringValue,
                   let number = item["number"]?.intValue {
                    pending.append(ComfyUIQueueItem(id: promptID, promptID: promptID, number: number))
                }
            }

            queueStatus = ComfyUIQueueStatus(runningItem: running, pendingItems: pending)
        } catch {
            // Non-fatal
        }
    }

    // MARK: - WebSocket

    private func connectWebSocket() async {
        do {
            try await client.connectWebSocket { [weak self] message in
                Task { @MainActor [weak self] in
                    await self?.handleWebSocketMessage(message)
                }
            }
        } catch {
            AppLogger.api.error("WebSocket connection failed: \(error)")
        }
    }

    private func handleWebSocketMessage(_ message: ComfyUIWebSocketMessage) async {
        guard let promptID = message.data.promptID else { return }

        switch message.type {
        case "execution_start":
            await updateExecution(id: promptID, status: .running, startedAt: Date())

        case "progress":
            if let value = message.data.value, let max = message.data.max, max > 0 {
                let progress = Double(value) / Double(max)
                await updateExecution(id: promptID, progress: progress)
            }

        case "executing":
            if let node = message.data.node {
                await updateExecution(id: promptID, currentNode: node)
            }

        case "execution_success":
            await completeExecution(id: promptID)

        case "execution_error":
            await updateExecution(id: promptID, status: .error, errorMessage: message.data.text)

        case "status":
            await refreshQueue()

        default:
            break
        }
    }

    private func updateExecution(
        id: String,
        status: ComfyUIExecutionStatus? = nil,
        progress: Double? = nil,
        currentNode: String? = nil,
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        errorMessage: String? = nil
    ) async {
        if let idx = executions.firstIndex(where: { $0.id == id }) {
            var exec = executions[idx]
            if let status = status { exec = updateExecution(exec, status: status) }
            if let progress = progress { exec = updateExecution(exec, progress: progress) }
            if let currentNode = currentNode { exec = updateExecution(exec, currentNode: currentNode) }
            if let startedAt = startedAt { exec = updateExecution(exec, startedAt: startedAt) }
            if let completedAt = completedAt { exec = updateExecution(exec, completedAt: completedAt) }
            if let errorMessage = errorMessage { exec = updateExecution(exec, errorMessage: errorMessage) }
            executions[idx] = exec
        }

        // Update DB record
        if let record = try? await executionRepository.getById(id: id) {
            var updated = record
            if let status = status { updated.status = status.rawValue }
            if let progress = progress { updated.progress = progress }
            if let currentNode = currentNode { updated.currentNode = currentNode }
            if let startedAt = startedAt { updated.startedAt = startedAt }
            if let completedAt = completedAt { updated.completedAt = completedAt }
            if let errorMessage = errorMessage { updated.errorMessage = errorMessage }
            _ = try? await executionRepository.update(execution: updated)
        }
    }

    private func updateExecution(_ exec: ComfyUIExecution, status: ComfyUIExecutionStatus) -> ComfyUIExecution {
        ComfyUIExecution(
            id: exec.id,
            workflowID: exec.workflowID,
            workflowName: exec.workflowName,
            status: status,
            progress: exec.progress,
            currentNode: exec.currentNode,
            startedAt: exec.startedAt,
            completedAt: exec.completedAt,
            outputs: exec.outputs,
            outputDirectory: exec.outputDirectory,
            errorMessage: exec.errorMessage
        )
    }

    private func updateExecution(_ exec: ComfyUIExecution, progress: Double) -> ComfyUIExecution {
        ComfyUIExecution(
            id: exec.id,
            workflowID: exec.workflowID,
            workflowName: exec.workflowName,
            status: exec.status,
            progress: progress,
            currentNode: exec.currentNode,
            startedAt: exec.startedAt,
            completedAt: exec.completedAt,
            outputs: exec.outputs,
            outputDirectory: exec.outputDirectory,
            errorMessage: exec.errorMessage
        )
    }

    private func updateExecution(_ exec: ComfyUIExecution, currentNode: String) -> ComfyUIExecution {
        ComfyUIExecution(
            id: exec.id,
            workflowID: exec.workflowID,
            workflowName: exec.workflowName,
            status: exec.status,
            progress: exec.progress,
            currentNode: currentNode,
            startedAt: exec.startedAt,
            completedAt: exec.completedAt,
            outputs: exec.outputs,
            outputDirectory: exec.outputDirectory,
            errorMessage: exec.errorMessage
        )
    }

    private func updateExecution(_ exec: ComfyUIExecution, startedAt: Date) -> ComfyUIExecution {
        ComfyUIExecution(
            id: exec.id,
            workflowID: exec.workflowID,
            workflowName: exec.workflowName,
            status: exec.status,
            progress: exec.progress,
            currentNode: exec.currentNode,
            startedAt: startedAt,
            completedAt: exec.completedAt,
            outputs: exec.outputs,
            outputDirectory: exec.outputDirectory,
            errorMessage: exec.errorMessage
        )
    }

    private func updateExecution(_ exec: ComfyUIExecution, completedAt: Date) -> ComfyUIExecution {
        ComfyUIExecution(
            id: exec.id,
            workflowID: exec.workflowID,
            workflowName: exec.workflowName,
            status: exec.status,
            progress: exec.progress,
            currentNode: exec.currentNode,
            startedAt: exec.startedAt,
            completedAt: completedAt,
            outputs: exec.outputs,
            outputDirectory: exec.outputDirectory,
            errorMessage: exec.errorMessage
        )
    }

    private func updateExecution(_ exec: ComfyUIExecution, errorMessage: String?) -> ComfyUIExecution {
        ComfyUIExecution(
            id: exec.id,
            workflowID: exec.workflowID,
            workflowName: exec.workflowName,
            status: exec.status,
            progress: exec.progress,
            currentNode: exec.currentNode,
            startedAt: exec.startedAt,
            completedAt: exec.completedAt,
            outputs: exec.outputs,
            outputDirectory: exec.outputDirectory,
            errorMessage: errorMessage
        )
    }

    private func completeExecution(id: String) async {
        // Fetch history to get outputs
        do {
            let history = try await client.getHistory(promptID: id)
            guard let entry = history.outputs[id] else {
                await updateExecution(id: id, status: .completed, completedAt: Date())
                return
            }

            var outputPaths: [String] = []
            let outputDir = executions.first(where: { $0.id == id })?.outputDirectory ?? defaultOutputDirectory()

            // Ensure output directory exists
            try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

            // Download images
            if let images = entry.outputs.first?.value.images {
                for image in images {
                    let data = try await client.downloadImage(
                        filename: image.filename,
                        subfolder: image.subfolder,
                        type: image.type
                    )
                    let outputPath = "\(outputDir)/\(image.filename)"
                    let outputURL = URL(fileURLWithPath: outputPath)
                    try data.write(to: outputURL)
                    outputPaths.append(outputPath)
                }
            }

            let pathsJSON = try JSONSerialization.data(withJSONObject: outputPaths)
            let pathsString = String(data: pathsJSON, encoding: .utf8) ?? "[]"

            // Update DB record
            if let record = try? await executionRepository.getById(id: id) {
                var updated = record
                updated.status = ComfyUIExecutionStatus.completed.rawValue
                updated.completedAt = Date()
                updated.outputPathsJson = pathsString
                _ = try? await executionRepository.update(execution: updated)
            }

            // Update local execution
            if let idx = executions.firstIndex(where: { $0.id == id }) {
                let exec = executions[idx]
                executions[idx] = ComfyUIExecution(
                    id: exec.id,
                    workflowID: exec.workflowID,
                    workflowName: exec.workflowName,
                    status: .completed,
                    progress: 1.0,
                    currentNode: exec.currentNode,
                    startedAt: exec.startedAt,
                    completedAt: Date(),
                    outputs: outputPaths,
                    outputDirectory: outputDir,
                    errorMessage: exec.errorMessage
                )
            }
        } catch {
            await updateExecution(id: id, status: .error, errorMessage: error.localizedDescription)
        }
    }

    // MARK: - Input Updates

    func updateInput(workflowID: String, nodeID: String, key: String, value: String) {
        guard let wIdx = workflows.firstIndex(where: { $0.id == workflowID }) else { return }
        guard let nIdx = workflows[wIdx].nodes.firstIndex(where: { $0.id == nodeID }) else { return }
        guard let iIdx = workflows[wIdx].nodes[nIdx].inputs.firstIndex(where: { $0.key == key }) else { return }

        var node = workflows[wIdx].nodes[nIdx]
        var inputs = node.inputs
        let param = inputs[iIdx]
        inputs[iIdx] = ComfyUIInputParameter(
            id: param.id,
            key: param.key,
            type: param.type,
            defaultValue: param.defaultValue,
            currentValue: value,
            options: param.options,
            minValue: param.minValue,
            maxValue: param.maxValue,
            step: param.step
        )
        node = ComfyUINode(id: node.id, classType: node.classType, inputs: inputs, isSubgraph: node.isSubgraph)

        var wf = workflows[wIdx]
        var nodes = wf.nodes
        nodes[nIdx] = node
        wf = ComfyUIWorkflow(id: wf.id, name: wf.name, path: wf.path, nodes: nodes)
        workflows[wIdx] = wf

        if selectedWorkflow?.id == workflowID {
            selectedWorkflow = wf
        }
    }

    // MARK: - Selection

    func selectWorkflow(id: String) {
        selectedWorkflow = workflows.first(where: { $0.id == id })
    }

    func selectExecution(id: String) {
        selectedExecution = executions.first(where: { $0.id == id })
    }

    // MARK: - Helpers

    func clearError() {
        errorMessage = nil
    }

    #if DEBUG
    func setConnected(_ connected: Bool) {
        isConnected = connected
    }
    #endif

    func disconnect() {
        Task {
            await client.disconnectWebSocket()
        }
        isConnected = false
    }
}
