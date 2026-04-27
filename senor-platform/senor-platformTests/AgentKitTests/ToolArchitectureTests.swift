import XCTest
@testable import senor_platform

private final class MockHTTPClient: ToolHTTPClient, @unchecked Sendable {
    func get(url: String, headers: [String: String]) async throws -> (data: Data, statusCode: Int) {
        (Data(), 200)
    }

    func post(url: String, body: Data, headers: [String: String]) async throws -> (data: Data, statusCode: Int) {
        (Data(), 200)
    }

    func download(url: String, to destination: URL) async throws {}

    func upload(url: String, file: URL, headers: [String: String]) async throws -> (data: Data, statusCode: Int) {
        (Data(), 200)
    }
}

private struct MockDeviantArtClient: AKDeviantArtClient {
    func stashSubmit(filename: String, title: String, tags: [String]?) async throws -> AKStashItem {
        AKStashItem(itemid: "stash", title: title)
    }

    func stashPublish(stashId: String, title: String, category: String?, isMature: Bool) async throws -> AKPublishResult {
        AKPublishResult(deviationid: "deviation", url: "https://example.com")
    }
}

private struct MockPatreonClient: AKPatreonClient {
    func createPost(campaignId: String, title: String, content: String, isPaid: Bool, isPublic: Bool, tiers: [String]?) async throws -> AKPost {
        AKPost(id: "post")
    }

    func getPublicURL(for postId: String) async throws -> String {
        "https://example.com/post"
    }
}

final class ToolArchitectureTests: XCTestCase {
    func testAppToolServiceProviderReturnsInjectedDependencies() async throws {
        let httpClient = MockHTTPClient()
        let fileManager = MockFileManager()
        let commandExecutor = MockCommandExecutor()
        let deviantArtClient = MockDeviantArtClient()
        let patreonClient = MockPatreonClient()

        let provider = AppToolServiceProvider(
            httpClientProvider: { httpClient },
            fileManagerProvider: { fileManager },
            commandExecutorProvider: { commandExecutor },
            configResolver: { key in key == "TOKEN" ? "secret" : nil },
            deviantArtClientProvider: { deviantArtClient },
            patreonClientProvider: { patreonClient }
        )

        let resolvedHTTPClient = try await provider.getHTTPClient()
        let resolvedFileManager = await provider.getFileManager()
        let resolvedCommandExecutor = await provider.getCommandExecutor()
        let token = try await provider.getConfig(key: "TOKEN")
        let resolvedDeviantArtClient = try await provider.getDeviantArtClient()
        let resolvedPatreonClient = try await provider.getPatreonClient()

        XCTAssertIdentical(resolvedHTTPClient as AnyObject, httpClient as AnyObject)
        XCTAssertIdentical(resolvedFileManager as AnyObject, fileManager)
        XCTAssertIdentical(resolvedCommandExecutor as AnyObject, commandExecutor)
        XCTAssertEqual(token, "secret")
        XCTAssertNotNil(resolvedDeviantArtClient)
        XCTAssertNotNil(resolvedPatreonClient)
    }

    func testToolCatalogLookupMatchesDeclaredToolTypes() {
        for toolType in AgentKit.toolTypes {
            let resolved = AgentKit.toolTypesByName[toolType.toolName]
            XCTAssertNotNil(resolved)
            XCTAssertEqual(
                // swiftlint:disable:next force_unwrapping
                ObjectIdentifier(resolved!),
                ObjectIdentifier(toolType)
            )
        }
    }

    func testToolSchemasCanBeMaterializedAndEncodedRepeatedly() throws {
        for _ in 0..<5 {
            let schemas = AgentKit.toolTypes.map {
                ToolDefinition(
                    name: $0.toolName,
                    description: $0.toolDescription,
                    inputSchema: $0.inputSchema,
                    outputSchema: $0.outputSchema
                )
            }

            let data = try JSONEncoder().encode(schemas)
            XCTAssertFalse(data.isEmpty)
        }
    }
}
