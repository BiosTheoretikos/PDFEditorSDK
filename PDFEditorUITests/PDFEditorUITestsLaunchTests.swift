import XCTest

final class PDFEditorUITestsLaunchTests: XCTestCase {
    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        false
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchTargetIsConfigured() throws {
        let app = XCUIApplication()

        XCTAssertFalse(app.exists)
    }
}
