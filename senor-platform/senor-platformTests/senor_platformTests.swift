//
//  senor_platformTests.swift
//  senor-platformTests
//
//  Created by Fahad Faruqi on 4/7/26.
//

import XCTest
@testable import senor_platform

final class senor_platformTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    // MARK: - View Model Tests
    
    func testAgentViewModelStatusColors() throws {
        let idleAgent = AgentViewModel(id: "1", name: "Test", status: .idle, lastActivity: nil, taskCount: 0)
        let runningAgent = AgentViewModel(id: "2", name: "Test", status: .running, lastActivity: nil, taskCount: 0)
        let errorAgent = AgentViewModel(id: "3", name: "Test", status: .error, lastActivity: nil, taskCount: 0)
        let offlineAgent = AgentViewModel(id: "4", name: "Test", status: .offline, lastActivity: nil, taskCount: 0)
        
        XCTAssertEqual(idleAgent.status.color, .green)
        XCTAssertEqual(runningAgent.status.color, .blue)
        XCTAssertEqual(errorAgent.status.color, .red)
        XCTAssertEqual(offlineAgent.status.color, .gray)
    }
    
    func testContentStatusCaseIterable() throws {
        let allStatuses = ContentItemViewModel.ContentStatus.allCases
        XCTAssertEqual(allStatuses.count, 4)
        XCTAssertTrue(allStatuses.contains(.pending))
        XCTAssertTrue(allStatuses.contains(.approved))
        XCTAssertTrue(allStatuses.contains(.published))
        XCTAssertTrue(allStatuses.contains(.rejected))
    }
    
    func testNameCategoryDisplayNames() throws {
        XCTAssertEqual(NameCategory.sciFi.displayName, "Sci-Fi")
        XCTAssertEqual(NameCategory.fantasy.displayName, "Fantasy")
        XCTAssertEqual(NameCategory.comics.displayName, "Comics")
        XCTAssertEqual(NameCategory.games.displayName, "Games")
        XCTAssertEqual(NameCategory.bollywood.displayName, "Bollywood")
    }
    
    // MARK: - Main View Enum Tests
    
    func testMainViewIcons() throws {
        XCTAssertEqual(MainView.dashboard.icon, "gauge.with.dots.needle.67percent")
        XCTAssertEqual(MainView.agents.icon, "cpu")
        XCTAssertEqual(MainView.tasks.icon, "list.bullet.rectangle")
        XCTAssertEqual(MainView.content.icon, "doc.text.image")
        XCTAssertEqual(MainView.approvals.icon, "checkmark.shield")
        XCTAssertEqual(MainView.settings.icon, "gear")
    }
    
    func testMainViewCaseIterable() throws {
        let allViews = MainView.allCases
        XCTAssertEqual(allViews.count, 6)
    }

    // MARK: - Performance Tests
    
    func testContentListPerformance() throws {
        self.measure {
            var items: [ContentItemViewModel] = []
            for i in 0..<1000 {
                items.append(ContentItemViewModel(
                    id: "\(i)",
                    title: "Item \(i)",
                    previewImage: nil,
                    createdAt: Date(),
                    status: .pending,
                    version: 1
                ))
            }
            XCTAssertEqual(items.count, 1000)
        }
    }
    
    func testAgentListPerformance() throws {
        self.measure {
            var agents: [AgentViewModel] = []
            for i in 0..<500 {
                agents.append(AgentViewModel(
                    id: "\(i)",
                    name: "Agent \(i)",
                    status: .idle,
                    lastActivity: Date(),
                    taskCount: i
                ))
            }
            XCTAssertEqual(agents.count, 500)
        }
    }

}
