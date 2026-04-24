import XCTest
@testable import AgentKit

final class AgentKitTests: XCTestCase {
    func testVersion() {
        XCTAssertEqual(AgentKit.version, "0.1.0")
    }
}
