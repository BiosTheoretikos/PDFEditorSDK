import PDFKit

enum UndoAction {
    case annotation(PDFAnnotation)
    case formFieldChange(annotation: PDFAnnotation, previousValue: String?, newValue: String?)
    case drawingSession(page: PDFPage, oldAnnotations: [PDFAnnotation], newAnnotations: [PDFAnnotation])
    case overlayTextBox(add: OverlayTextBoxState?, remove: OverlayTextBoxState?)
    case overlayTextBoxUpdate(before: OverlayTextBoxState, after: OverlayTextBoxState)
    case moveAnnotation(annotation: PDFAnnotation, from: CGRect, to: CGRect)
    case overlayImage(add: OverlayImageState?, remove: OverlayImageState?)
    case overlayImageUpdate(before: OverlayImageState, after: OverlayImageState)
    case deleteInkAnnotation(annotation: PDFAnnotation, page: PDFPage)
    case overlayShape(add: OverlayShapeState?, remove: OverlayShapeState?)
    case overlayShapeUpdate(before: OverlayShapeState, after: OverlayShapeState)
    case addPage(page: PDFPage, at: Int)
    case removePage(page: PDFPage, at: Int)
}
