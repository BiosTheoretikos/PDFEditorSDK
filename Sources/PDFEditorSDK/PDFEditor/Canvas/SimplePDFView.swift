import SwiftUI
import PDFKit
import UIKit

struct SimplePDFView: UIViewRepresentable {
    @Bindable var viewModel: PDFFormViewModel

    func makeUIView(context: Context) -> DrawingPDFView {
        let pdfView = DrawingPDFView()
        pdfView.document = viewModel.pdfDocument
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .systemGroupedBackground
        pdfView.setFormFieldEntryEnabled(true)
        pdfView.formViewModel = viewModel

        viewModel.pdfView = pdfView

        return pdfView
    }

    func updateUIView(_ pdfView: DrawingPDFView, context: Context) {
        if pdfView.document !== viewModel.pdfDocument {
            pdfView.document = viewModel.pdfDocument
            pdfView.goToFirstPage(nil)
        }
        if viewModel.needsOverlayRestore {
            DispatchQueue.main.async {
                viewModel.restoreOverlaysIfNeeded()
                viewModel.needsOverlayRestore = false
            }
        }
        pdfView.isDrawingMode = viewModel.isDrawingMode
        pdfView.isTextMode = viewModel.isTextMode
        pdfView.isSelectMode = viewModel.isSelectMode
        pdfView.isFormMode = viewModel.activeTool == .form
        pdfView.currentInkColor = viewModel.inkColor
        pdfView.currentLineWidth = viewModel.inkLineWidth
        pdfView.isEraserMode = viewModel.isEraserMode
        pdfView.eraserRadius = viewModel.eraserRadius
        pdfView.textBoxBackgroundColor = viewModel.textBoxBackgroundColor
        pdfView.textBoxFontSize = viewModel.textBoxFontSize
        pdfView.textBoxIsBold = viewModel.textBoxIsBold
        pdfView.textBoxTextColor = viewModel.textBoxTextColor
        pdfView.textBoxTextAlignment = viewModel.textBoxTextAlignment
        pdfView.textBoxVerticalAlignment = viewModel.textBoxVerticalAlignment
        pdfView.textBoxBorderWidth = viewModel.textBoxBorderWidth
        pdfView.textBoxBorderColor = viewModel.textBoxBorderColor
        pdfView.isShapeMode = viewModel.activeTool == .shape
        pdfView.currentShapeKind = viewModel.activeShapeKind
        pdfView.shapeStrokeColor = viewModel.shapeStrokeColor
        pdfView.shapeLineWidth = viewModel.shapeLineWidth
        pdfView.isPencilKitMode = viewModel.activeTool == .pencilKit
        pdfView.setFormFieldEntryEnabled(viewModel.activeTool == .form)
        pdfView.isUserInteractionEnabled = !viewModel.pageScrollLocked
        pdfView.formFieldHighlightFilter = viewModel.shouldHighlightFormField
        pdfView.drawWithFinger = viewModel.drawWithFinger
        pdfView.pencilOnlyAnnotations = viewModel.pencilOnlyAnnotations
    }
}
