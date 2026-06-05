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
        pdfView.currentInkColor = viewModel.drawingSettings.inkColor
        pdfView.currentLineWidth = viewModel.drawingSettings.lineWidth
        pdfView.isEraserMode = viewModel.isEraserMode
        pdfView.eraserRadius = viewModel.drawingSettings.eraserRadius
        pdfView.textBoxBackgroundColor = viewModel.textSettings.backgroundColor
        pdfView.textBoxFontSize = viewModel.textSettings.fontSize
        pdfView.textBoxIsBold = viewModel.textSettings.isBold
        pdfView.textBoxTextColor = viewModel.textSettings.textColor
        pdfView.textBoxTextAlignment = viewModel.textSettings.textAlignment
        pdfView.textBoxVerticalAlignment = viewModel.textSettings.verticalAlignment
        pdfView.textBoxBorderWidth = viewModel.textSettings.borderWidth
        pdfView.textBoxBorderColor = viewModel.textSettings.borderColor
        pdfView.isShapeMode = viewModel.activeTool == .shape
        pdfView.currentShapeKind = viewModel.shapeSettings.kind
        pdfView.shapeStrokeColor = viewModel.shapeSettings.strokeColor
        pdfView.shapeLineWidth = viewModel.shapeSettings.lineWidth
        pdfView.isPencilKitMode = viewModel.activeTool == .pencilKit
        pdfView.setFormFieldEntryEnabled(viewModel.activeTool == .form)
        pdfView.isUserInteractionEnabled = !viewModel.pageScrollLocked
        pdfView.formFieldHighlightFilter = viewModel.shouldHighlightFormField
        pdfView.drawWithFinger = viewModel.pencilInput.drawWithFinger
        pdfView.pencilOnlyAnnotations = viewModel.pencilInput.pencilOnlyAnnotations
    }
}
