import XCTest

final class PDFEditorUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testXCUIAutomationCanCreateApplicationProxy() throws {
        let app = XCUIApplication()

        XCTAssertFalse(app.exists)
    }
}
