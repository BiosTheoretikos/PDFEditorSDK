import PDFKit
import Testing
import UIKit
@testable import PDFEditor

struct PDFFormViewModelImagePickingTests {
    @Test
    @MainActor
    func presentingFormWidgetImageSourceStoresPendingTarget() throws {
        try PDFEditorTestSupport.withPreservedEditorPreferences {
            let viewModel = try makeLoadedViewModel()
            let annotation = PDFAnnotation(bounds: .zero, forType: .widget, withProperties: nil)

            viewModel.presentFormWidgetImageSourceChoice(pageIndex: 0, annotation: annotation)

            #expect(viewModel.pendingFormWidgetPageIndex == 0)
            #expect(viewModel.pendingFormWidgetAnnotation === annotation)
            #expect(viewModel.showFormWidgetImageSourceDialog)
        }
    }

    @Test
    @MainActor
    func cancelPendingFormWidgetImagePickClearsPendingState() throws {
        try PDFEditorTestSupport.withPreservedEditorPreferences {
            let viewModel = try makeLoadedViewModel()
            let annotation = PDFAnnotation(bounds: .zero, forType: .widget, withProperties: nil)
            viewModel.presentFormWidgetImageSourceChoice(pageIndex: 0, annotation: annotation)
            viewModel.imagePickIsForFormWidget = true

            viewModel.cancelPendingFormWidgetImagePick()

            #expect(viewModel.pendingFormWidgetPageIndex == nil)
            #expect(viewModel.pendingFormWidgetAnnotation == nil)
            #expect(viewModel.imagePickIsForFormWidget == false)
        }
    }

    @Test
    @MainActor
    func beginningFormWidgetImagePickMarksNextImageAsFormWidgetImage() throws {
        try PDFEditorTestSupport.withPreservedEditorPreferences {
            let viewModel = try makeLoadedViewModel()
            viewModel.showFormWidgetImageSourceDialog = true

            viewModel.beginFormWidgetImagePickFromLibrary()

            #expect(viewModel.imagePickIsForFormWidget)
            #expect(viewModel.showFormWidgetImageSourceDialog == false)
        }
    }

    @Test
    @MainActor
    func handlingFormWidgetImagePickerResultAlwaysClearsPendingState() throws {
        try PDFEditorTestSupport.withPreservedEditorPreferences {
            let viewModel = try makeLoadedViewModel()
            let annotation = PDFAnnotation(bounds: .zero, forType: .widget, withProperties: nil)
            viewModel.presentFormWidgetImageSourceChoice(pageIndex: 0, annotation: annotation)
            viewModel.beginFormWidgetImagePickFromCamera()

            viewModel.handleImagePickedFromSheet(UIImage())

            #expect(viewModel.imagePickIsForFormWidget == false)
            #expect(viewModel.pendingFormWidgetPageIndex == nil)
            #expect(viewModel.pendingFormWidgetAnnotation == nil)
        }
    }

    @MainActor
    private func makeLoadedViewModel() throws -> PDFFormViewModel {
        let document = PDFEditorDocument(
            pdfDocument: try PDFEditorTestSupport.makePDFDocument()
        )
        return PDFFormViewModel(document: document)
    }
}
