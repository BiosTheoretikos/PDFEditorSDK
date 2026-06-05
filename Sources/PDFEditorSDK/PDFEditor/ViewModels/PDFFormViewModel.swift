//
//  PDFFormViewModel.swift
//  PDFEditorSDK
//
//  Extracted from PDFEditorView.swift
//

import SwiftUI
import PDFKit
import UIKit
import CoreText

// MARK: - View Model
@MainActor
@Observable
class PDFFormViewModel {
    var preferences: EditorPreferences

    func persistPreferences() {
        preferences.save()
    }

    var pdfDocument: PDFDocument?
    var activeTool: EditorTool = .form
    var undoStack: [UndoAction] = []
    var redoStack: [UndoAction] = []
    var pageScrollLocked: Bool = false
    var hasTextSelection: Bool = false
    var hasSelectedInkAnnotation: Bool = false
    var hasSelectedOverlayObject: Bool = false
    weak var pdfView: DrawingPDFView?

    var drawingSettings: DrawingAnnotationSettings {
        didSet {
            drawingSettings.apply(to: &preferences)
            persistPreferences()
        }
    }
    var textSettings: TextAnnotationSettings {
        didSet {
            textSettings.normalize()
            textSettings.apply(to: &preferences)
            persistPreferences()
        }
    }
    /// Reflects the border state of the currently selected text box (not persisted — synced on selection).
    var selectedTextBoxBorder = TextBoxBorderSelectionSettings()
    var shapeSettings: ShapeAnnotationSettings {
        didSet {
            shapeSettings.apply(to: &preferences)
            persistPreferences()
        }
    }
    var imageSettings: ImageAnnotationSettings {
        didSet {
            imageSettings.apply(to: &preferences)
            persistPreferences()
        }
    }
    var pencilInput: PencilInputSettings {
        didSet {
            pencilInput.normalize()
            pencilInput.apply(to: &preferences)
            persistPreferences()
        }
    }
    var previousTool: EditorTool? = nil
    var displaySettings: EditorDisplaySettings {
        didSet {
            displaySettings.apply(to: &preferences)
            persistPreferences()
        }
    }
    var lineWidthControls: LineWidthControlSettings {
        didSet {
            lineWidthControls.normalize()
            lineWidthControls.apply(to: &preferences)
            persistPreferences()
        }
    }

    var saveStatus: String?
    var exportStatus: String?
    var openStatus: String?
    var currentDocumentURL: URL?
    var lastSavedURL: URL?
    let maxUndoActions = 50
    var didLoadOverlayMetadata = false
    var pendingOverlayMetadata: OverlayDocumentMetadata?
    var needsOverlayRestore = false
    var currentPageIndex: Int = 0
    var pageCount: Int = 0

    /// When true, the image picker result is placed into the tapped PDF form widget instead of a free overlay.
    var imagePickIsForFormWidget = false
    var showFormWidgetImageSourceDialog = false
    var pendingFormWidgetPageIndex: Int?
    var pendingFormWidgetAnnotation: PDFAnnotation?
    let editableSaveHandler: PDFEditorFileHandler?
    let flattenedExportHandler: PDFEditorFileHandler?
    let shouldHighlightFormField: ((PDFFormFieldInfo) -> Bool)?

    init(
        documentURL: URL,
        editableSaveHandler: PDFEditorFileHandler? = nil,
        flattenedExportHandler: PDFEditorFileHandler? = nil,
        shouldHighlightFormField: ((PDFFormFieldInfo) -> Bool)? = nil
    ) {
        self.editableSaveHandler = editableSaveHandler
        self.flattenedExportHandler = flattenedExportHandler
        self.shouldHighlightFormField = shouldHighlightFormField
        
        let prefs = EditorPreferences.load()
        self.preferences = prefs
        
        self.drawingSettings = DrawingAnnotationSettings(preferences: prefs)
        self.textSettings = TextAnnotationSettings(preferences: prefs)
        self.shapeSettings = ShapeAnnotationSettings(preferences: prefs)
        self.imageSettings = ImageAnnotationSettings(preferences: prefs)
        self.pencilInput = PencilInputSettings(preferences: prefs)
        self.displaySettings = EditorDisplaySettings(preferences: prefs)
        self.lineWidthControls = LineWidthControlSettings(preferences: prefs)

        _ = loadPDF(from: documentURL)
        
    }
    
    var selectedOverlayKind: SelectedOverlayKind?

    var isDrawingMode: Bool { activeTool == .draw }
    var isEraserMode: Bool { activeTool == .erase }
    var isTextMode: Bool { activeTool == .text }
    var isSelectMode: Bool { activeTool == .select }
    var isShapeMode: Bool { activeTool == .shape }
    var isPencilKitMode: Bool { activeTool == .pencilKit }
    
    func setTool(_ tool: EditorTool) {
        // Tapping an already-active tool returns to select mode
        if activeTool == tool, tool != .select {
            previousTool = activeTool
            activeTool = .select
            pdfView?.endOverlayTextEditing()

            return
        }
        if tool == .shape {
            previousTool = activeTool
            activeTool = .shape
            pdfView?.endOverlayTextEditing()
            hasSelectedInkAnnotation = false
            pdfView?.deselectInkAnnotation()
            pdfView?.deselectOverlaySelection()
            return
        }
        if tool == .pencilKit {
            previousTool = activeTool
            activeTool = .pencilKit
            pdfView?.endOverlayTextEditing()
            hasSelectedInkAnnotation = false
            pdfView?.deselectInkAnnotation()
            pdfView?.deselectOverlaySelection()
            return
        }
        if tool != .text {
            pdfView?.endOverlayTextEditing()
        }
        previousTool = activeTool
        activeTool = tool
        if tool != .select {
            hasSelectedInkAnnotation = false
            pdfView?.deselectInkAnnotation()
            pdfView?.deselectOverlaySelection()
        }
        }

    func applyShapeStyleToSelected() {
        pdfView?.applyShapeStyleToSelected(kind: shapeSettings.kind, strokeColor: shapeSettings.strokeColor, lineWidth: shapeSettings.lineWidth)
        }

    func updateShapeSettings(_ update: (inout ShapeAnnotationSettings) -> Void) {
        update(&shapeSettings)
        guard activeTool == .select else { return }
        applyShapeStyleToSelected()
        }

    func applyImageBorderToSelected() {
        pdfView?.applyImageBorderToSelected(borderWidth: imageSettings.borderWidth, borderColor: imageSettings.borderColor)
        }

    func applyTextBorderToSelected() {
        pdfView?.applyTextBorderToSelected(borderWidth: selectedTextBoxBorder.width, borderColor: selectedTextBoxBorder.color)
        }

    /// Updates width + canvas; use from toolbar instead of assigning `selectedTextBoxBorder.width` so selection sync does not go through `.onChange`.
    func commitSelectedTextBoxBorderWidth(_ width: CGFloat) {
        selectedTextBoxBorder.width = width
        applyTextBorderToSelected()
        }

    /// Updates color + canvas; use from toolbar instead of assigning `selectedTextBoxBorder.color` so selection sync does not go through `.onChange`.
    func commitSelectedTextBoxBorderColor(_ color: UIColor) {
        selectedTextBoxBorder.color = color
        applyTextBorderToSelected()
        }

    func commitImageBorderWidth(_ width: CGFloat) {
            imageSettings.borderWidth = width
        applyImageBorderToSelected()
        }

    func commitImageBorderColor(_ color: UIColor) {
            imageSettings.borderColor = color
        applyImageBorderToSelected()
        }
    func toggleScrollLock() {
        pageScrollLocked.toggle()
        }
    
    func highlightSelectedText() {
        pdfView?.highlightCurrentSelection()
        }
    
    func addAnnotation(_ annotation: PDFAnnotation) {
        didMakeChange(.annotation(annotation))
        }
    
    func recordFormFieldChange(annotation: PDFAnnotation, previousValue: String?, newValue: String?) {
        didMakeChange(.formFieldChange(annotation: annotation, previousValue: previousValue, newValue: newValue))
        }
    
    func addImage(_ image: UIImage) {
        pdfView?.addOverlayImage(image)
        }

    func updateTextSettings(_ update: (inout TextAnnotationSettings) -> Void) {
        update(&textSettings)
        applyTextStyleToSelectedTextBox()
        }

    func applyTextStyleToSelectedTextBox() {
        pdfView?.applyTextStyleToSelectedTextBox(
            fontSize: textSettings.fontSize,
            isBold: textSettings.isBold,
            textColor: textSettings.textColor,
            backgroundColor: textSettings.backgroundColor,
            textAlignment: textSettings.textAlignment,
            verticalAlignment: textSettings.verticalAlignment
        )
        }
    // Call this whenever a fresh change is made to clear the redo stack
    func didMakeChange(_ action: UndoAction) {
        undoStack.append(action)
        if undoStack.count > maxUndoActions {
            undoStack.removeFirst(undoStack.count - maxUndoActions)
        }
        redoStack.removeAll()
        }
    
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    
    func deleteSelectedSelection() {
        if hasSelectedInkAnnotation {
            deleteSelectedInkAnnotation()
        } else {
            pdfView?.deleteSelectedOverlayObject()
        }
        }
    
    func deleteSelectedInkAnnotation() {
        guard let pdfView, let annotation = pdfView.selectedInkAnnotation,
              let page = annotation.page else { return }
        page.removeAnnotation(annotation) 
        pdfView.deselectInkAnnotation()
        didMakeChange(.deleteInkAnnotation(annotation: annotation, page: page))
        }
    
    func flushActiveFormFieldChangesIfNeeded() {
        pdfView?.flushPendingFormFieldUndoTracking()
        }
}

// MARK: - PencilGestureHandler Conformance
extension PDFFormViewModel: PencilGestureHandler {}
