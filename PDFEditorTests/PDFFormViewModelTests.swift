import Foundation
import PDFKit
import Testing
@testable import PDFEditor

struct PDFFormViewModelTests {
    @Test
    @MainActor
    func loadsDocumentFromURLAndTracksPageMetrics() throws {
        try PDFEditorTestSupport.withPreservedEditorPreferences {
            let pdfURL = try PDFEditorTestSupport.makeTemporaryPDFURL(pageCount: 2)
            defer { try? FileManager.default.removeItem(at: pdfURL.deletingLastPathComponent()) }

            let viewModel = PDFFormViewModel(documentURL: pdfURL)

            #expect(viewModel.pdfDocument?.pageCount == 2)
            #expect(viewModel.currentDocumentURL == pdfURL)
            #expect(viewModel.pageCount == 2)
            #expect(viewModel.currentPageIndex == 0)
            #expect(viewModel.openStatus == nil)
        }
    }

    @Test
    @MainActor
    func missingDocumentURLLeavesViewModelUnloadedWithOpenStatus() {
        PDFEditorTestSupport.withPreservedEditorPreferences {
            let missingURL = URL(fileURLWithPath: "/tmp/missing-\(UUID().uuidString).pdf")

            let viewModel = PDFFormViewModel(documentURL: missingURL)

            #expect(viewModel.pdfDocument == nil)
            #expect(viewModel.pageCount == 0)
            #expect(viewModel.openStatus == "Failed to open PDF")
        }
    }

    @Test
    @MainActor
    func loadsReferenceDocumentAsEditableCopy() throws {
        try PDFEditorTestSupport.withPreservedEditorPreferences {
            let referenceDocument = PDFEditorDocument(
                pdfDocument: try PDFEditorTestSupport.makePDFDocument(pageCount: 2)
            )
            let viewModel = PDFFormViewModel(document: referenceDocument)

            viewModel.pdfDocument?.removePage(at: 0)
            let referencePageCount = referenceDocument.withPDFDocument { document in
                document.pageCount
            }

            #expect(viewModel.pdfDocument?.pageCount == 1)
            #expect(referencePageCount == 2)
            #expect(viewModel.currentDocumentURL == nil)
            #expect(viewModel.pageCount == 2)
        }
    }

    @Test
    @MainActor
    func pageNavigationIgnoresOutOfRangeIndexes() throws {
        try PDFEditorTestSupport.withPreservedEditorPreferences {
            let viewModel = try makeLoadedViewModel(pageCount: 3)

            viewModel.goToPage(index: 1)
            #expect(viewModel.currentPageIndex == 1)

            viewModel.goToNextPage()
            #expect(viewModel.currentPageIndex == 2)

            viewModel.goToNextPage()
            #expect(viewModel.currentPageIndex == 2)

            viewModel.goToPreviousPage()
            #expect(viewModel.currentPageIndex == 1)

            viewModel.goToPage(index: -1)
            #expect(viewModel.currentPageIndex == 1)
        }
    }

    @Test
    @MainActor
    func addBlankPageClampsInsertIndexAndRecordsUndo() throws {
        try PDFEditorTestSupport.withPreservedEditorPreferences {
            let viewModel = try makeLoadedViewModel(pageCount: 1)

            viewModel.addBlankPage(at: 99)

            #expect(viewModel.pdfDocument?.pageCount == 2)
            #expect(viewModel.pageCount == 2)
            #expect(viewModel.currentPageIndex == 1)
            #expect(viewModel.canUndo)
            #expect(viewModel.undoStack.count == 1)
        }
    }

    @Test
    @MainActor
    func undoRedoRestoresAddedPages() throws {
        try PDFEditorTestSupport.withPreservedEditorPreferences {
            let viewModel = try makeLoadedViewModel(pageCount: 1)

            viewModel.addBlankPage(at: 1)
            viewModel.undo()

            #expect(viewModel.pdfDocument?.pageCount == 1)
            #expect(viewModel.pageCount == 1)
            #expect(viewModel.canRedo)

            viewModel.redo()

            #expect(viewModel.pdfDocument?.pageCount == 2)
            #expect(viewModel.pageCount == 2)
            #expect(viewModel.canUndo)
        }
    }

    @Test
    @MainActor
    func undoRedoRestoresRemovedPages() throws {
        try PDFEditorTestSupport.withPreservedEditorPreferences {
            let viewModel = try makeLoadedViewModel(pageCount: 2)

            viewModel.goToPage(index: 1)
            viewModel.removeCurrentPage()

            #expect(viewModel.pdfDocument?.pageCount == 1)
            #expect(viewModel.pageCount == 1)
            #expect(viewModel.canUndo)

            viewModel.undo()

            #expect(viewModel.pdfDocument?.pageCount == 2)
            #expect(viewModel.pageCount == 2)
            #expect(viewModel.currentPageIndex == 1)

            viewModel.redo()

            #expect(viewModel.pdfDocument?.pageCount == 1)
            #expect(viewModel.pageCount == 1)
        }
    }

    @Test
    @MainActor
    func undoStackCapsAtMaximumAndFreshChangesClearRedo() throws {
        try PDFEditorTestSupport.withPreservedEditorPreferences {
            let viewModel = try makeLoadedViewModel(pageCount: 1)
            viewModel.redoStack.append(makeAnnotationAction())

            for _ in 0..<60 {
                viewModel.didMakeChange(makeAnnotationAction())
            }

            #expect(viewModel.undoStack.count == viewModel.maxUndoActions)
            #expect(viewModel.redoStack.isEmpty)
        }
    }

    @Test
    @MainActor
    func toolSelectionTracksPreviousToolAndTogglesActiveToolToSelect() throws {
        try PDFEditorTestSupport.withPreservedEditorPreferences {
            let viewModel = try makeLoadedViewModel(pageCount: 1)

            viewModel.setTool(.draw)
            #expect(viewModel.activeTool == .draw)
            #expect(viewModel.previousTool == .form)
            #expect(viewModel.isDrawingMode)

            viewModel.setTool(.draw)
            #expect(viewModel.activeTool == .select)
            #expect(viewModel.previousTool == .draw)
            #expect(viewModel.isSelectMode)

            viewModel.setTool(.shape)
            #expect(viewModel.activeTool == .shape)
            #expect(viewModel.previousTool == .select)
            #expect(viewModel.isShapeMode)
        }
    }

    @MainActor
    private func makeLoadedViewModel(pageCount: Int) throws -> PDFFormViewModel {
        let document = PDFEditorDocument(
            pdfDocument: try PDFEditorTestSupport.makePDFDocument(pageCount: pageCount)
        )
        return PDFFormViewModel(document: document)
    }

    private func makeAnnotationAction() -> UndoAction {
        .annotation(PDFAnnotation(bounds: .zero, forType: .text, withProperties: nil))
    }
}
