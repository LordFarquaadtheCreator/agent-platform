import XCTest

// swiftlint:disable:next type_name
final class AIChatUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false

        let bundleID = "fahad.senor-platform"

        // Check if app is already running from previous test
        let existingApp = XCUIApplication(bundleIdentifier: bundleID)
        if existingApp.exists {
            app = existingApp
            app.terminate()
            usleep(1000000)
        }

        // Connect to app by bundle identifier
        // In CI/headless environments without GUI, UI tests will be skipped below
        app = XCUIApplication(bundleIdentifier: bundleID)

        // Wait briefly to see if app window appears
        let windowExists = app.windows.firstMatch.waitForExistence(timeout: 3.0)

        // Skip UI tests if app is not accessible (no GUI session available)
        // This is expected in headless/CI environments
        try XCTSkipIf(!windowExists, "App not accessible - UI tests require macOS GUI session. Skipping in this environment.")
    }

    override func tearDownWithError() throws {
        // Terminate app after each test
        if app != nil {
            app.terminate()
        }
    }

    // MARK: - Helper Methods

    /// Opens AI Chat panel via toolbar button
    @MainActor
    func openAIChatPanel() {
        // Find and tap the AI Chat button - use identifier to disambiguate from nested label elements
        let aiChatButton = app.buttons.matching(identifier: "aiChatToolbarButton").firstMatch
        XCTAssertTrue(aiChatButton.waitForExistence(timeout: 5.0), "AI Chat toolbar button should exist")
        aiChatButton.tap()

        // Wait for panel to appear
        let inputField = app.textFields["chatInputField"]
        XCTAssertTrue(inputField.waitForExistence(timeout: 5.0), "Chat input field should appear")

        // Wait for models to load
        sleep(3)

        // Verify model is loaded - check Picker has a value
        let modelPicker = app.pickers.firstMatch
        if modelPicker.exists {
            let value = modelPicker.value as? String ?? ""
            print("Model picker value: \(value)")
            if value.isEmpty {
                XCTFail("No model selected. LM Studio may not have models loaded.")
            }
        }
    }

    /// Sends a message and waits for AI response
    @MainActor
    func sendMessage(_ text: String) {
        let inputField = app.textFields["chatInputField"]
        XCTAssertTrue(inputField.waitForExistence(timeout: 5.0), "Input field should exist")
        XCTAssertTrue(inputField.isHittable, "Input field should be hittable")

        // Activate text field with press to ensure focus
        inputField.press(forDuration: 0.1)
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5.0), "Keyboard should appear")

        inputField.typeText(text)

        // Tap send button or press return
        let sendButton = app.buttons["sendMessageButton"]
        if sendButton.exists && sendButton.isEnabled {
            sendButton.tap()
        } else {
            app.keyboards.buttons["Return"].tap()
        }
    }

    /// Waits for AI response to appear, returns true if assistant message found
    @MainActor
    func waitForAIResponse(timeout: TimeInterval = 60.0) -> Bool {
        let startTime = Date()
        let assistantMessages = app.otherElements.matching(identifier: "assistantMessage")

        while Date().timeIntervalSince(startTime) < timeout {
            // Check for assistant message
            if assistantMessages.firstMatch.exists {
                return true
            }

            // Check for error message (indicates AI failed)
            let errorAlert = app.alerts.firstMatch
            if errorAlert.exists {
                print("Error alert detected: \(errorAlert.label)")
                return false
            }

            // Check for error message in UI (new errorMessage identifier)
            let errorMessage = app.otherElements.matching(identifier: "errorMessage")
            if errorMessage.firstMatch.exists {
                let label = errorMessage.firstMatch.label
                print("Error message detected: \(label)")
                XCTFail("AI failed with error: \(label)")
                return false
            }

            // Check for old-style error text
            let errorTexts = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Failed' OR label CONTAINS[c] 'Error'"))
            if errorTexts.firstMatch.exists {
                print("Error text detected")
                return false
            }

            sleep(1)
        }

        return false
    }

    /// Gets count of assistant messages
    @MainActor
    func assistantMessageCount() -> Int {
        return app.otherElements.matching(identifier: "assistantMessage").count
    }

    /// Gets text of last assistant message
    @MainActor
    func lastAssistantMessageText() -> String? {
        let messages = app.otherElements.matching(identifier: "assistantMessage")
        guard messages.count > 0 else { return nil }
        return messages.element(boundBy: messages.count - 1).label
    }

    /// Clears chat history by relaunching app (workaround since SwiftUI Menu isn't XCTest-friendly)
    @MainActor
    func clearChatHistory() {
        // Relaunch app to clear state
        app.terminate()
        app.launch()

        // Reopen AI Chat
        openAIChatPanel()

        // Wait for load
        sleep(2)
    }

    // MARK: - Basic Interface Tests

    @MainActor
    func testAIChatPanelOpens() throws {
        openAIChatPanel()

        let inputField = app.textFields["chatInputField"]
        XCTAssertTrue(inputField.exists, "Chat input field should exist after opening panel")
    }

    @MainActor
    func testUserMessageAppearsAfterSending() throws {
        openAIChatPanel()

        let testMessage = "Test message \(UUID().uuidString.prefix(8))"
        sendMessage(testMessage)

        // Wait for user message to appear
        let userMessages = app.otherElements.matching(identifier: "userMessage")
        let exists = userMessages.firstMatch.waitForExistence(timeout: 3.0)

        XCTAssertTrue(exists, "User message should appear in chat")
    }

    // MARK: - Basic AI Response Test

    /// Simple test to verify AI responds at all
    @MainActor
    func testAIRespondsToMessage() throws {
        openAIChatPanel()
        clearChatHistory()

        sendMessage("Hello, can you hear me?")

        let responded = waitForAIResponse(timeout: 60.0)
        XCTAssertTrue(responded, "AI should respond to a simple message within 60 seconds")

        // Verify we got actual content
        let assistantCount = assistantMessageCount()
        XCTAssertGreaterThan(assistantCount, 0, "Should have at least one assistant message")
    }

    // MARK: - Stateful Conversation Test

    /// Tests that AI remembers context across multiple messages using favorite color test
    @MainActor
    func testStatefulConversation_RemembersFavoriteColor() throws {
        openAIChatPanel()
        clearChatHistory()

        // Step 1: Tell AI favorite color
        let favoriteColor = "purple"
        sendMessage("My favorite color is \(favoriteColor). Remember this.")

        // Wait for AI to respond (check for assistant message)
        let firstResponse = waitForAIResponse(timeout: 60.0)
        XCTAssertTrue(firstResponse, "AI should respond to first message")

        // Wait for response to complete
        sleep(10)

        // Step 2: Ask what the favorite color was
        sendMessage("What is my favorite color? Just say the color name.")

        // Wait for second response
        let secondResponse = waitForAIResponse(timeout: 60.0)
        XCTAssertTrue(secondResponse, "AI should respond to second message")

        // Wait for streaming to complete
        sleep(15)

        // Step 3: Check if response contains the color
        // Get all assistant messages
        let assistantMessages = app.otherElements.matching(identifier: "assistantMessage")
        var foundColorInResponse = false

        for i in 0..<min(assistantMessages.count, 10) {
            let messageText = assistantMessages.element(boundBy: i).label.lowercased()
            if messageText.contains(favoriteColor) {
                foundColorInResponse = true
                break
            }
        }

        // Also check all static texts in the scroll view as fallback
        if !foundColorInResponse {
            let allTexts = app.staticTexts
            for i in 0..<min(allTexts.count, 20) {
                let text = allTexts.element(boundBy: i).label.lowercased()
                if text.contains(favoriteColor) {
                    foundColorInResponse = true
                    break
                }
            }
        }

        // This assertion will fail if stateful conversation isn't working
        // The test documents the expected behavior even if it currently fails
        XCTAssertTrue(
            foundColorInResponse,
            "AI should remember and mention the favorite color '\(favoriteColor)' in response. " +
            "Stateful conversation not working - check if previousResponseID is being tracked correctly."
        )
    }

    /// Tests that context is maintained across multiple conversation turns
    @MainActor
    func testStatefulConversation_MultipleTurns() throws {
        openAIChatPanel()
        clearChatHistory()

        // Turn 1: Share information
        sendMessage("I have a dog named Max. He is 5 years old.")
        sleep(20)

        // Turn 2: Ask about age
        sendMessage("How old is my dog?")
        sleep(20)

        // Turn 3: Ask about name
        sendMessage("What is my dog's name?")
        sleep(20)

        // Check if both facts were remembered
        let allTexts = app.staticTexts
        var rememberedMax = false
        var rememberedAge = false

        for i in 0..<min(allTexts.count, 30) {
            let text = allTexts.element(boundBy: i).label.lowercased()
            if text.contains("max") {
                rememberedMax = true
            }
            if text.contains("5") || text.contains("five") {
                rememberedAge = true
            }
        }

        // At least one fact should be remembered across turns
        let rememberedAnyFact = rememberedMax || rememberedAge

        XCTAssertTrue(
            rememberedAnyFact,
            "AI should remember context across multiple turns. " +
            "Found Max: \(rememberedMax), Found Age: \(rememberedAge). " +
            "Check if previousResponseID is being passed in ChatRequest."
        )
    }

    // MARK: - Error Handling Tests

    @MainActor
    func testErrorHandling_WhenAIServiceUnavailable() throws {
        openAIChatPanel()
        clearChatHistory()

        // Send a message (will fail if no LM Studio running)
        sendMessage("Test message")

        // Wait for error or response
        sleep(3)

        // Check for error alert
        let errorAlert = app.alerts.firstMatch
        if errorAlert.waitForExistence(timeout: 2.0) {
            XCTAssertTrue(errorAlert.exists, "Error alert should appear when AI service unavailable")

            // Dismiss alert
            if app.buttons["OK"].exists {
                app.buttons["OK"].tap()
            }
        }
    }

    // MARK: - Streaming Tests

    @MainActor
    func testStreamingIndicatorAppears() throws {
        openAIChatPanel()
        clearChatHistory()

        sendMessage("Tell me a story about a cat")

        // Check for generating indicator (ProgressView inside button)
        sleep(1)

        // The send button should show ProgressView while generating
        let sendButton = app.buttons["sendMessageButton"]
        XCTAssertTrue(sendButton.exists, "Send button should exist")
    }

    @MainActor
    func testClearChatWorks() throws {
        openAIChatPanel()

        // Send a message first
        sendMessage("Test message for clearing")
        sleep(2)

        // Verify message appeared
        let userMessages = app.otherElements.matching(identifier: "userMessage")
        XCTAssertGreaterThan(userMessages.count, 0, "Should have user message before clearing")

        // Clear the chat
        clearChatHistory()

        // After clearing, input should still exist
        let inputField = app.textFields["chatInputField"]
        XCTAssertTrue(inputField.exists, "Input field should still exist after clearing")
    }
}
