import Testing
@testable import PDFEditor

struct PencilGestureHandlerTests {
    @Test
    @MainActor
    func toggleEraserSwitchesBetweenDrawAndEraseTools() {
        let handler = PencilGestureHandlerSpy(activeTool: .draw)

        handler.perform(.toggleEraser)
        #expect(handler.activeTool == .erase)

        handler.perform(.toggleEraser)
        #expect(handler.activeTool == .draw)
    }

    @Test
    @MainActor
    func undoAndRedoActionsForwardToHistoryMethods() {
        let handler = PencilGestureHandlerSpy(activeTool: .form)

        handler.perform(.undo)
        handler.perform(.redo)

        #expect(handler.undoCallCount == 1)
        #expect(handler.redoCallCount == 1)
    }

    @Test
    @MainActor
    func switchToLastToolOnlyRunsWhenPreviousToolExists() {
        let handler = PencilGestureHandlerSpy(activeTool: .text)

        handler.perform(.switchToLastTool)
        #expect(handler.setToolCalls.isEmpty)

        handler.previousTool = .shape
        handler.perform(.switchToLastTool)

        #expect(handler.activeTool == .shape)
        #expect(handler.setToolCalls == [.shape])
    }

    @Test
    @MainActor
    func directActivationActionsSelectExpectedTools() {
        let handler = PencilGestureHandlerSpy(activeTool: .form)

        handler.perform(.activateSelect)
        handler.perform(.activateDraw)
        handler.perform(.activateEraser)
        handler.perform(.activateText)
        handler.perform(.activateShape)

        #expect(handler.setToolCalls == [.select, .draw, .erase, .text, .shape])
        #expect(handler.activeTool == .shape)
    }

    @Test func pencilGestureActionMetadataMatchesPickerPresentation() {
        #expect(PencilGestureAction.noAction.displayName == "None")
        #expect(PencilGestureAction.toggleEraser.systemImage == "eraser")
        #expect(PencilGestureAction.noAction.isExclusive == false)
        #expect(PencilGestureAction.activateShape.isExclusive)
        #expect(PencilGestureAction.allCases.map(\.id).contains("activate_shape"))
    }
}

@MainActor
private final class PencilGestureHandlerSpy: PencilGestureHandler {
    var activeTool: EditorTool
    var previousTool: EditorTool?
    var undoCallCount = 0
    var redoCallCount = 0
    var setToolCalls: [EditorTool] = []

    init(activeTool: EditorTool) {
        self.activeTool = activeTool
    }

    func undo() {
        undoCallCount += 1
    }

    func redo() {
        redoCallCount += 1
    }

    func setTool(_ tool: EditorTool) {
        previousTool = activeTool
        activeTool = tool
        setToolCalls.append(tool)
    }
}
