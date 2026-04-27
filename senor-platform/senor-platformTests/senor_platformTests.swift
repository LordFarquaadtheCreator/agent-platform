import XCTest
@testable import senor_platform

final class senor_platformTests: XCTestCase {

    func testAppSectionIconsRemainStable() {
        XCTAssertEqual(AppSection.dashboard.icon, "gauge.with.dots.needle.67percent")
        XCTAssertEqual(AppSection.agents.icon, "cpu")
        XCTAssertEqual(AppSection.tasks.icon, "list.bullet.rectangle")
        XCTAssertEqual(AppSection.content.icon, "doc.text.image")
        XCTAssertEqual(AppSection.approvals.icon, "checkmark.shield")
        XCTAssertEqual(AppSection.settings.icon, "gear")
    }

    func testLoadTaskCreationContextUseCaseSortsMappedModels() async throws {
        let useCase = LoadTaskCreationContextUseCase(
            agentRepository: MockAgentRepository(agents: [
                AgentRecord(displayName: "Zulu", nameSource: "manual", nameSeed: 0),
                AgentRecord(displayName: "Alpha", nameSource: "manual", nameSeed: 0)
            ]),
            taskTypeRepository: MockTaskTypeRepository(taskTypes: [
                TaskTypeRecord(name: "Poster", schemaVersion: 1, jsonSchema: "{}"),
                TaskTypeRecord(name: "Announcement", schemaVersion: 1, jsonSchema: "{}")
            ])
        )

        let result = try await useCase.execute()

        XCTAssertEqual(result.agents.map(\.displayName), ["Alpha", "Zulu"])
        XCTAssertEqual(result.taskTypes.map(\.name), ["Announcement", "Poster"])
    }

    func testCreateAgentUseCasePersistsMappedAgent() async throws {
        let repository = MockAgentRepository()
        let useCase = CreateAgentUseCase(agentRepository: repository)

        let created = try await useCase.execute(
            AgentDraft(
                displayName: "Builder-01",
                isActive: true,
                description: "Creates content",
                workerScriptPath: "/tmp/worker",
                configJSON: "{}"
            )
        )

        XCTAssertEqual(created.displayName, "Builder-01")
        XCTAssertEqual(created.status, .idle)
        let createdAgents = await repository.createdAgentNames()
        XCTAssertEqual(createdAgents.first, "Builder-01")
    }

    @MainActor
    func testCreateTaskUseCaseRejectsInvalidMetadataJSON() async throws {
        let taskRepository = MockTaskRepository()
        let scheduleRepository = MockTaskScheduleRepository()
        let useCase = CreateTaskUseCase(
            taskRepository: taskRepository,
            scheduleRepository: scheduleRepository,
            settingsService: SettingsService()
        )

        await XCTAssertThrowsErrorAsync(
            try await useCase.execute(
                TaskDraft(
                    agentId: "agent-1",
                    taskTypeId: "task-type-1",
                    taskName: "Broken Task",
                    metadataJSON: "{invalid",
                    schedule: nil
                )
            )
        ) { error in
            guard case AppError.invalidJSON = error else {
                return XCTFail("Expected invalidJSON error, got \(error)")
            }
        }

        let createdTasks = await taskRepository.createdTasksSnapshot()
        XCTAssertTrue(createdTasks.isEmpty)
    }

    @MainActor
    func testCreateTaskUseCaseCreatesTaskAndSchedule() async throws {
        let taskRepository = MockTaskRepository()
        let scheduleRepository = MockTaskScheduleRepository()
        let settingsService = SettingsService()
        settingsService.setTaskScriptPath("/tmp/senor-task")
        defer { settingsService.setTaskScriptPath(nil) }

        let useCase = CreateTaskUseCase(
            taskRepository: taskRepository,
            scheduleRepository: scheduleRepository,
            settingsService: settingsService
        )

        let result = try await useCase.execute(
            TaskDraft(
                agentId: "agent-1",
                taskTypeId: "task-type-1",
                taskName: "Daily Poster",
                metadataJSON: "{\"prompt\":\"Hello\"}",
                schedule: .daily(time: Date(timeIntervalSince1970: 3600), timezone: "America/New_York")
            )
        )

        XCTAssertEqual(result.name, "Daily Poster")
        let createdTasks = await taskRepository.createdTasksSnapshot()
        let createdSchedules = await scheduleRepository.createdSchedulesSnapshot()
        XCTAssertEqual(createdTasks.count, 1)
        XCTAssertEqual(createdTasks.first?.goScriptPath, "/tmp/senor-task")
        XCTAssertEqual(createdSchedules.count, 1)
        XCTAssertEqual(createdSchedules.first?.scheduleKind, ScheduleKind.recurring.rawValue)
    }

    func testTaskScheduleSelectionTitles() {
        XCTAssertEqual(TaskScheduleSelection.oneTime.title, "One Time")
        XCTAssertEqual(TaskScheduleSelection.daily.title, "Daily")
        XCTAssertEqual(TaskScheduleSelection.weekly.title, "Weekly")
        XCTAssertEqual(TaskScheduleSelection.monthly.title, "Monthly")
    }

    func testDomainModelsDoNotReferencePersistenceRecords() throws {
        let appModels = try sourceFileContents(
            pathComponents: ["senor-platform", "Domain", "AppModels.swift"]
        )
        XCTAssertFalse(appModels.contains("Record"))
    }

    func testFeatureAndSharedUiCodeDoesNotResolveGlobals() throws {
        let featuresRoot = repositoryRoot()
            .appendingPathComponent("senor-platform")
            .appendingPathComponent("Features")
        let sharedUiRoot = repositoryRoot()
            .appendingPathComponent("senor-platform")
            .appendingPathComponent("SharedUI")

        let featureFiles = try sourceFiles(in: featuresRoot)
        let sharedUiFiles = try sourceFiles(in: sharedUiRoot)
        let allFiles = featureFiles + sharedUiFiles

        for file in allFiles {
            let contents = try String(contentsOf: file, encoding: .utf8)
            XCTAssertFalse(contents.contains("sharedContainer"), "Unexpected global resolution in \(file.path)")
            XCTAssertFalse(contents.contains("EventBus"), "Unexpected event bus dependency in \(file.path)")
        }
    }

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func sourceFileContents(pathComponents: [String]) throws -> String {
        let url = pathComponents.reduce(repositoryRoot()) { partialResult, component in
            partialResult.appendingPathComponent(component)
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func sourceFiles(in directory: URL) throws -> [URL] {
        let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: nil
        )
        var files: [URL] = []

        while let file = enumerator?.nextObject() as? URL {
            guard file.pathExtension == "swift" else { continue }
            files.append(file)
        }

        return files
    }
}

private func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ errorHandler: (Error) -> Void = { _ in }
) async {
    do {
        _ = try await expression()
        XCTFail("Expected expression to throw")
    } catch {
        errorHandler(error)
    }
}

private actor MockAgentRepository: AgentRepository {
    private(set) var agents: [AgentRecord]
    private(set) var createdAgents: [AgentRecord] = []

    init(agents: [AgentRecord] = []) {
        self.agents = agents
    }

    func create(agent: AgentRecord) async throws -> AgentRecord {
        createdAgents.append(agent)
        agents.append(agent)
        return agent
    }

    func update(agent: AgentRecord) async throws -> AgentRecord { agent }
    func delete(id: String) async throws {}
    func getById(id: String) async throws -> AgentRecord? { agents.first { $0.id == id } }
    func getByDisplayName(name: String) async throws -> AgentRecord? { agents.first { $0.displayName == name } }
    func listAll() async throws -> [AgentRecord] { agents }
    func listActive() async throws -> [AgentRecord] { agents }
    func existsWithName(name: String) async throws -> Bool { agents.contains { $0.displayName == name } }
    func createdAgentNames() -> [String] { createdAgents.map(\.displayName) }
}

private actor MockTaskRepository: TaskRepository {
    private(set) var createdTasks: [TaskRecord] = []

    func create(task: TaskRecord) async throws -> TaskRecord {
        createdTasks.append(task)
        return task
    }

    func update(task: TaskRecord) async throws -> TaskRecord { task }
    func delete(id: String) async throws {}
    func getById(id: String) async throws -> TaskRecord? { createdTasks.first { $0.id == id } }
    func listByAgent(agentId: String) async throws -> [TaskRecord] { createdTasks.filter { $0.agentId == agentId } }
    func listEnabled() async throws -> [TaskRecord] { createdTasks.filter(\.isEnabled) }
    func countByAgent(agentId: String) async throws -> Int { createdTasks.filter { $0.agentId == agentId }.count }
    func createdTasksSnapshot() -> [TaskRecord] { createdTasks }
}

private actor MockTaskScheduleRepository: TaskScheduleRepository {
    private(set) var createdSchedules: [TaskScheduleRecord] = []

    func create(schedule: TaskScheduleRecord) async throws -> TaskScheduleRecord {
        createdSchedules.append(schedule)
        return schedule
    }

    func update(schedule: TaskScheduleRecord) async throws -> TaskScheduleRecord { schedule }
    func delete(id: String) async throws {}
    func getById(id: String) async throws -> TaskScheduleRecord? { createdSchedules.first { $0.id == id } }
    func getByTask(taskId: String) async throws -> TaskScheduleRecord? { createdSchedules.first { $0.taskId == taskId } }
    func listDue(before: Date) async throws -> [TaskScheduleRecord] { createdSchedules }
    func listActive() async throws -> [TaskScheduleRecord] { createdSchedules.filter(\.isActive) }
    func createdSchedulesSnapshot() -> [TaskScheduleRecord] { createdSchedules }
}

private actor MockTaskTypeRepository: TaskTypeRepository {
    private let taskTypes: [TaskTypeRecord]

    init(taskTypes: [TaskTypeRecord] = []) {
        self.taskTypes = taskTypes
    }

    func create(taskType: TaskTypeRecord) async throws -> TaskTypeRecord { taskType }
    func update(taskType: TaskTypeRecord) async throws -> TaskTypeRecord { taskType }
    func delete(id: String) async throws {}
    func getById(id: String) async throws -> TaskTypeRecord? { taskTypes.first { $0.id == id } }
    func getByName(name: String) async throws -> TaskTypeRecord? { taskTypes.first { $0.name == name } }
    func listAll() async throws -> [TaskTypeRecord] { taskTypes }
}
