import XCTest
@testable import senor_platform

final class AgentKitTests: XCTestCase {
    func testVersion() {
        XCTAssertEqual(AgentKit.version, "0.1.0")
    }

    func testToolCatalogHasUniqueNames() {
        let names = AgentKit.toolTypes.map { $0.toolName }
        XCTAssertEqual(Set(names).count, names.count)
        XCTAssertEqual(AgentKit.toolNames, names.sorted())
    }

    func testExpandedToolCatalogIncludesFilesystemEnvironmentAndPublishingTools() {
        let expected: Set<String> = [
            "read_file",
            "create_file",
            "write_file",
            "delete_file",
            "move_file",
            "copy_file",
            "read_file_chunk",
            "list_directory",
            "create_directory",
            "delete_directory",
            "search_files",
            "path_exists",
            "get_file_info",
            "run_command",
            "get_environment",
            "get_working_directory",
            "comfyui",
            "image_composer",
            "deviantart_publish",
            "patreon_publish",
        ]

        XCTAssertEqual(Set(AgentKit.toolNames), expected)
    }

    func testToolRegistryCanRegisterEntireCatalog() async {
        let registry = ToolRegistry()

        for toolType in AgentKit.toolTypes {
            await registry.register(toolType)
        }

        let registeredNames = await registry.listTools()
        XCTAssertEqual(Set(registeredNames), Set(AgentKit.toolNames))

        let schemas = await registry.getAllToolSchemas()
        XCTAssertEqual(schemas.count, AgentKit.toolNames.count)
        XCTAssertTrue(schemas.allSatisfy { !$0.description.isEmpty })
    }
}
