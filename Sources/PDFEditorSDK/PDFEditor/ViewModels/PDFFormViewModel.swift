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
    private var preferences: EditorPreferences
    private let preferencesScope: EditorPreferencesScope = .pdf

    private func persistPreferences() {
        preferences.save(scope: preferencesScope)
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
    var inkColor: UIColor {
        didSet { preferences.inkColor = RGBAColor(inkColor); persistPreferences()}
    }
    var inkLineWidth: CGFloat {
        didSet { preferences.inkLineWidth = inkLineWidth; persistPreferences()}
    }
    var eraserRadius: CGFloat {
        didSet { preferences.eraserRadius = eraserRadius; persistPreferences()}
    }
    var textBoxBackgroundColor: UIColor {
        didSet { preferences.textBoxBackgroundColor = RGBAColor(textBoxBackgroundColor); persistPreferences()}
    }
    var textBoxFontSize: CGFloat {
        didSet {
            if textBoxFontSize < 1 {
                textBoxFontSize = 1
                return
            }
            preferences.textBoxFontSize = textBoxFontSize
            persistPreferences()
        }
    }
    var textBoxIsBold: Bool {
        didSet { preferences.textBoxIsBold = textBoxIsBold; persistPreferences()}
    }
    var textBoxTextColor: UIColor {
        didSet { preferences.textBoxTextColor = RGBAColor(textBoxTextColor); persistPreferences()}
    }
    var textBoxTextAlignment: NSTextAlignment {
        didSet { preferences.textBoxTextAlignment = textBoxTextAlignment.rawValue; persistPreferences()}
    }
    var textBoxVerticalAlignment: TextVerticalAlignment {
        didSet { preferences.textBoxVerticalAlignment = textBoxVerticalAlignment.rawValue; persistPreferences()}
    }
    var textBoxBorderWidth: CGFloat {
        didSet { preferences.textBoxBorderWidth = textBoxBorderWidth; persistPreferences() }
    }
    var textBoxBorderColor: UIColor {
        didSet { preferences.textBoxBorderColor = RGBAColor(textBoxBorderColor); persistPreferences() }
    }
    /// Reflects the border state of the currently selected text box (not persisted — synced on selection).
    var selectedTextBoxBorderWidth: CGFloat = 0
    var selectedTextBoxBorderColor: UIColor = .black
    var activeShapeKind: OverlayShapeKind {
        didSet { preferences.activeShapeKind = activeShapeKind; persistPreferences()}
    }
    var shapeStrokeColor: UIColor {
        didSet { preferences.shapeStrokeColor = RGBAColor(shapeStrokeColor); persistPreferences()}
    }
    var shapeLineWidth: CGFloat {
        didSet { preferences.shapeLineWidth = shapeLineWidth; persistPreferences()}
    }
    var imageBorderWidth: CGFloat {
        didSet { preferences.imageBorderWidth = imageBorderWidth; persistPreferences()}
    }
    var imageBorderColor: UIColor {
        didSet { preferences.imageBorderColor = RGBAColor(imageBorderColor); persistPreferences()}
    }
    var drawWithFinger: Bool {
        didSet { preferences.drawWithFinger = drawWithFinger; persistPreferences() }
    }
    var pencilOnlyAnnotations: Bool {
        didSet { preferences.pencilOnlyAnnotations = pencilOnlyAnnotations; persistPreferences() }
    }
    var pencilDoubleTapAction: PencilGestureAction {
        didSet { preferences.pencilDoubleTapAction = pencilDoubleTapAction; persistPreferences() }
    }
    var pencilSqueezeAction: PencilGestureAction {
        didSet { preferences.pencilSqueezeAction = pencilSqueezeAction; persistPreferences() }
    }
    var pencilDoubleSqueezeAction: PencilGestureAction {
        didSet { preferences.pencilDoubleSqueezeAction = pencilDoubleSqueezeAction; persistPreferences() }
    }
    var previousTool: EditorTool? = nil
    var isThumbnailOverlayVisible: Bool {
        didSet { preferences.isThumbnailOverlayVisible = isThumbnailOverlayVisible; persistPreferences() }
    }
    var toolbarCompact: Bool {
        didSet { preferences.toolbarCompact = toolbarCompact; persistPreferences() }
    }
    var toolOptionsPresentation: ToolOptionsPresentation {
        didSet { preferences.toolOptionsPresentation = toolOptionsPresentation; persistPreferences() }
    }
    var lineWidthInputStyle: LineWidthInputStyle {
        didSet { preferences.lineWidthInputStyle = lineWidthInputStyle; persistPreferences() }
    }
    var lineWidthStep: CGFloat {
        didSet {
            var p = preferences
            p.lineWidthStep = lineWidthStep
            p.normalizeLineWidthControlFields()
            if p.lineWidthStep != lineWidthStep {
                lineWidthStep = p.lineWidthStep
                return
            }
            preferences.lineWidthStep = p.lineWidthStep
            persistPreferences()
        }
    }
    var lineWidthMax: CGFloat {
        didSet {
            var p = preferences
            p.lineWidthMax = lineWidthMax
            p.normalizeLineWidthControlFields()
            if p.lineWidthMax != lineWidthMax {
                lineWidthMax = p.lineWidthMax
                return
            }
            preferences.lineWidthMax = p.lineWidthMax
            persistPreferences()
        }
    }
    var saveStatus: String?
    var exportStatus: String?
    var openStatus: String?
    var currentDocumentURL: URL?
    var lastSavedURL: URL?
    private let maxUndoActions = 50
    private var didLoadOverlayMetadata = false
    private var pendingOverlayMetadata: OverlayDocumentMetadata?
    var needsOverlayRestore = false
    var currentPageIndex: Int = 0
    var pageCount: Int = 0
    
    /// When true, the image picker result is placed into the tapped PDF form widget instead of a free overlay.
    var imagePickIsForFormWidget = false
    var showFormWidgetImageSourceDialog = false
    private var pendingFormWidgetPageIndex: Int?
    private var pendingFormWidgetAnnotation: PDFAnnotation?
    private let editableSaveHandler: PDFEditorFileHandler?
    private let flattenedExportHandler: PDFEditorFileHandler?
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
        
        let prefs = EditorPreferences.load(scope: preferencesScope)
        self.preferences = prefs
        
        self.inkColor = prefs.inkColor.uiColor
        self.inkLineWidth = prefs.inkLineWidth
        
        self.eraserRadius = prefs.eraserRadius
        
        self.textBoxBackgroundColor = prefs.textBoxBackgroundColor.uiColor
        self.textBoxFontSize = max(1, prefs.textBoxFontSize)
        self.textBoxIsBold = prefs.textBoxIsBold
        self.textBoxTextColor = prefs.textBoxTextColor.uiColor
        self.textBoxTextAlignment = NSTextAlignment(rawValue: prefs.textBoxTextAlignment) ?? .left
        self.textBoxVerticalAlignment = TextVerticalAlignment(rawValue: prefs.textBoxVerticalAlignment) ?? .top
        self.textBoxBorderWidth = prefs.textBoxBorderWidth
        self.textBoxBorderColor = prefs.textBoxBorderColor.uiColor

        self.activeShapeKind = prefs.activeShapeKind
        self.shapeStrokeColor = prefs.shapeStrokeColor.uiColor
        self.shapeLineWidth = prefs.shapeLineWidth
        
        self.imageBorderWidth = prefs.imageBorderWidth
        self.imageBorderColor = prefs.imageBorderColor.uiColor

        self.drawWithFinger = prefs.drawWithFinger
        self.pencilOnlyAnnotations = prefs.pencilOnlyAnnotations
        self.pencilDoubleTapAction = prefs.pencilDoubleTapAction
        self.pencilSqueezeAction = prefs.pencilSqueezeAction
        self.pencilDoubleSqueezeAction = prefs.pencilDoubleSqueezeAction
        self.isThumbnailOverlayVisible = prefs.isThumbnailOverlayVisible
        self.toolbarCompact = prefs.toolbarCompact
        self.toolOptionsPresentation = prefs.toolOptionsPresentation

        self.lineWidthInputStyle = prefs.lineWidthInputStyle
        self.lineWidthStep = prefs.lineWidthStep
        self.lineWidthMax = prefs.lineWidthMax

        _ = loadPDF(from: documentURL)
        
    }
    
    var selectedOverlayKind: SelectedOverlayKind?

    var isDrawingMode: Bool { activeTool == .draw }
    var isEraserMode: Bool { activeTool == .erase }
    var isTextMode: Bool { activeTool == .text }
    var isSelectMode: Bool { activeTool == .select }
    var isShapeMode: Bool { activeTool == .shape }
    var isPencilKitMode: Bool { activeTool == .pencilKit }
    
    @discardableResult
    func loadPDF(from url: URL) -> Bool {
        currentDocumentURL = url
        guard let document = PDFDocument(url: url) else {
            openStatus = "Failed to open PDF"
            return false
        }
        pendingOverlayMetadata = extractRealOverlayMetadata(from: document)
        pdfDocument = document
        didLoadOverlayMetadata = false
        needsOverlayRestore = true
        updatePageMetrics()
        return true
    }
    
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
        pdfView?.applyShapeStyleToSelected(kind: activeShapeKind, strokeColor: shapeStrokeColor, lineWidth: shapeLineWidth)
    }

    func applyImageBorderToSelected() {
        pdfView?.applyImageBorderToSelected(borderWidth: imageBorderWidth, borderColor: imageBorderColor)
    }

    func applyTextBorderToSelected() {
        pdfView?.applyTextBorderToSelected(borderWidth: selectedTextBoxBorderWidth, borderColor: selectedTextBoxBorderColor)
    }

    /// Updates width + canvas; use from toolbar instead of assigning `selectedTextBoxBorderWidth` so selection sync does not go through `.onChange`.
    func commitSelectedTextBoxBorderWidth(_ width: CGFloat) {
        selectedTextBoxBorderWidth = width
        applyTextBorderToSelected()
    }

    /// Updates color + canvas; use from toolbar instead of assigning `selectedTextBoxBorderColor` so selection sync does not go through `.onChange`.
    func commitSelectedTextBoxBorderColor(_ color: UIColor) {
        selectedTextBoxBorderColor = color
        applyTextBorderToSelected()
    }

    func commitImageBorderWidth(_ width: CGFloat) {
        imageBorderWidth = width
        applyImageBorderToSelected()
    }

    func commitImageBorderColor(_ color: UIColor) {
        imageBorderColor = color
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
    
    func presentFormWidgetImageSourceChoice(pageIndex: Int, annotation: PDFAnnotation) {
        pendingFormWidgetPageIndex = pageIndex
        pendingFormWidgetAnnotation = annotation
        showFormWidgetImageSourceDialog = true
    }
    
    func cancelPendingFormWidgetImagePick() {
        pendingFormWidgetPageIndex = nil
        pendingFormWidgetAnnotation = nil
        imagePickIsForFormWidget = false
    }
    
    func beginFormWidgetImagePickFromCamera() {
        imagePickIsForFormWidget = true
        showFormWidgetImageSourceDialog = false
    }
    
    func beginFormWidgetImagePickFromLibrary() {
        imagePickIsForFormWidget = true
        showFormWidgetImageSourceDialog = false
    }
    
    func handleImagePickedFromSheet(_ image: UIImage?) {
        if imagePickIsForFormWidget {
            let pageIndex = pendingFormWidgetPageIndex
            let annotation = pendingFormWidgetAnnotation
            imagePickIsForFormWidget = false
            pendingFormWidgetPageIndex = nil
            pendingFormWidgetAnnotation = nil
            guard let image,
                  let pageIndex,
                  let annotation,
                  let page = pdfDocument?.page(at: pageIndex) else { return }
            pdfView?.addOverlayImage(image, forFormWidget: annotation, on: page)
            return
        }
        if let image {
            addImage(image)
        }
    }
    
    func applyTextStyleToSelectedTextBox() {
        pdfView?.applyTextStyleToSelectedTextBox(
            fontSize: textBoxFontSize,
            isBold: textBoxIsBold,
            textColor: textBoxTextColor,
            backgroundColor: textBoxBackgroundColor,
            textAlignment: textBoxTextAlignment,
            verticalAlignment: textBoxVerticalAlignment
        )
    }

    func updatePageMetrics() {
        pageCount = pdfDocument?.pageCount ?? 0
        if let page = pdfView?.currentPage, let document = pdfDocument {
            currentPageIndex = document.index(for: page)
        } else {
            currentPageIndex = 0
        }
    }
    
    func goToPage(index: Int) {
        guard let document = pdfDocument, index >= 0, index < document.pageCount else { return }
        if let page = document.page(at: index) {
            pdfView?.go(to: page)
            currentPageIndex = index
        }
    }
    
    func goToNextPage() {
        goToPage(index: currentPageIndex + 1)
    }
    
    func goToPreviousPage() {
        goToPage(index: currentPageIndex - 1)
    }
    
    func removeCurrentPage() {
        guard let document = pdfDocument, document.pageCount > 1 else { return }
        let index = currentPageIndex
        guard let page = document.page(at: index) else { return }
        document.removePage(at: index)
        updatePageMetrics()
        goToPage(index: max(0, index - 1))
        didMakeChange(.removePage(page: page, at: index))
    }

    func addBlankPage(at insertIndex: Int) {
        guard let document = pdfDocument else { return }
        let pageSize = pdfView?.currentPage?.bounds(for: .mediaBox).size ?? CGSize(width: 612, height: 792)
        let renderer = UIGraphicsImageRenderer(size: pageSize)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: pageSize))
        }
        guard let page = PDFPage(image: image) else { return }
        let safeInsertIndex = max(0, min(insertIndex, document.pageCount))
        document.insert(page, at: safeInsertIndex)
        updatePageMetrics()
        goToPage(index: safeInsertIndex)
        didMakeChange(.addPage(page: page, at: safeInsertIndex))
    }
    
    func restoreOverlaysIfNeeded() {
        guard !didLoadOverlayMetadata else { return }
        if let pendingOverlayMetadata {
            pdfView?.restoreOverlayMetadata(pendingOverlayMetadata)
            self.pendingOverlayMetadata = nil
        } else {
            pdfView?.readOverlayMetadata()
        }
        didLoadOverlayMetadata = true
    }

    private func extractRealOverlayMetadata(from document: PDFDocument) -> OverlayDocumentMetadata? {
        let overlayKey = PDFOverlayRenderer.overlayAnnotationKey
        var textMetas: [OverlayTextBoxMeta] = []
        var imageMetas: [OverlayImageMeta] = []
        var shapeMetas: [OverlayShapeMeta] = []
        var toRemove: [(PDFPage, PDFAnnotation)] = []
        let decoder = JSONDecoder()

        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            for annotation in page.annotations {
                guard let raw = annotation.value(forAnnotationKey: overlayKey) as? String else { continue }
                toRemove.append((page, annotation))

                let parts = raw.split(separator: ":", maxSplits: 1)
                guard parts.count == 2,
                      let jsonData = Data(base64Encoded: String(parts[1])) else { continue }

                switch parts[0] {
                case "text":
                    if let meta = try? decoder.decode(OverlayTextBoxMeta.self, from: jsonData) {
                        textMetas.append(meta)
                    }
                case "image":
                    if let meta = try? decoder.decode(OverlayImageMeta.self, from: jsonData) {
                        imageMetas.append(meta)
                    }
                case "shape":
                    if let meta = try? decoder.decode(OverlayShapeMeta.self, from: jsonData) {
                        shapeMetas.append(meta)
                    }
                default:
                    continue
                }
            }
        }

        guard !toRemove.isEmpty else { return nil }
        for (page, annotation) in toRemove {
            page.removeAnnotation(annotation)
        }
        return OverlayDocumentMetadata(textBoxes: textMetas, images: imageMetas, shapes: shapeMetas)
    }
    
    func undo() {
        prepareForFormUndoRedo()
        guard let action = undoStack.popLast() else { return }
        let resolved = resolveOverlayStateIfNeeded(action)
        redoStack.append(resolved)
        performUndoAction(resolved)
    }
    
    func redo() {
        prepareForFormUndoRedo()
        guard let action = redoStack.popLast() else { return }
        undoStack.append(action)
        
        performRedoAction(action)
    }

    private func prepareForFormUndoRedo() {
        guard let pdfView else { return }
        pdfView.commitActiveFormWidgetTextToAnnotations()
        pdfView.flushPendingFormFieldUndoTracking()
        pdfView.endEditing(true)
    }

    private func resolveOverlayStateIfNeeded(_ action: UndoAction) -> UndoAction {
        switch action {
        case .overlayTextBox(let add, let remove):
            if let add, let current = pdfView?.overlayTextBoxState(id: add.id) {
                return .overlayTextBox(add: current, remove: remove)
            }
            return action
        case .overlayImage(let add, let remove):
            if let add, let current = pdfView?.overlayImageState(id: add.id) {
                return .overlayImage(add: current, remove: remove)
            }
            return action
        case .overlayShape(let add, let remove):
            if let add, let current = pdfView?.overlayShapeState(id: add.id) {
                return .overlayShape(add: current, remove: remove)
            }
            return action
        case .overlayTextBoxUpdate(let before, let after):
            if let current = pdfView?.overlayTextBoxState(id: after.id) {
                return .overlayTextBoxUpdate(before: before, after: current)
            }
            return action
        default:
            return action
        }
    }
    
    private func performUndoAction(_ action: UndoAction) {
            switch action {
            case .annotation(let ann):
                ann.page?.removeAnnotation(ann)
            case .formFieldChange(let ann, let prev, _):
                applyFormFieldValue(annotation: ann, value: prev)
            case .drawingSession(let page, let old, let new):
                if let sel = pdfView?.selectedInkAnnotation, new.contains(where: { $0 === sel }) {
                    pdfView?.deselectInkAnnotation()
                }
                new.forEach { page.removeAnnotation($0) }
                old.forEach { page.addAnnotation($0) }
            case .overlayTextBox(let add, let remove):
                if let add {
                    pdfView?.removeOverlayTextBox(id: add.id)
                }
                if let remove {
                    pdfView?.addOverlayTextBox(from: remove)
                }
            case .overlayTextBoxUpdate(let before, _):
                pdfView?.updateOverlayTextBox(from: before)
            case .moveAnnotation(let ann, let from, _):
                pdfView?.suppressGoTo = true
                ann.bounds = from
                pdfView?.suppressGoTo = false
                if pdfView?.selectedInkAnnotation === ann {
                    pdfView?.deselectInkAnnotation()
                }
            case .overlayImage(let add, let remove):
                if let add {
                    pdfView?.removeOverlayImage(id: add.id)
                }
                if let remove {
                    pdfView?.addOverlayImage(from: remove)
                }
            case .overlayImageUpdate(let before, _):
                pdfView?.updateOverlayImage(from: before)
            case .deleteInkAnnotation(let ann, let page):
                page.addAnnotation(ann)
            case .overlayShape(let add, let remove):
                if let add { pdfView?.removeOverlayShape(id: add.id) }
                if let remove { pdfView?.addOverlayShape(from: remove) }
            case .overlayShapeUpdate(let before, _):
                pdfView?.updateOverlayShape(from: before)
            case .addPage(_, let at):
                guard let document = pdfDocument else { return }
                document.removePage(at: at)
                updatePageMetrics()
                goToPage(index: max(0, at - 1))
            case .removePage(let page, let at):
                guard let document = pdfDocument else { return }
                let safeIndex = max(0, min(at, document.pageCount))
                document.insert(page, at: safeIndex)
                updatePageMetrics()
                goToPage(index: safeIndex)
            }
        }

    private func performRedoAction(_ action: UndoAction) {
            switch action {
            case .annotation(let ann):
                ann.page?.addAnnotation(ann)
            case .formFieldChange(let ann, _, let newValue):
                applyFormFieldValue(annotation: ann, value: newValue)
            case .drawingSession(let page, let old, let new):
                old.forEach { page.removeAnnotation($0) }
                new.forEach { page.addAnnotation($0) }
            case .overlayTextBox(let add, let remove):
                if let add {
                    pdfView?.addOverlayTextBox(from: add)
                }
                if let remove {
                    pdfView?.removeOverlayTextBox(id: remove.id)
                }
            case .overlayTextBoxUpdate(_, let after):
                pdfView?.updateOverlayTextBox(from: after)
            case .moveAnnotation(let ann, _, let to):
                pdfView?.suppressGoTo = true
                ann.bounds = to
                pdfView?.suppressGoTo = false
                if pdfView?.selectedInkAnnotation === ann {
                    pdfView?.deselectInkAnnotation()
                }
            case .overlayImage(let add, let remove):
                if let add {
                    pdfView?.addOverlayImage(from: add)
                }
                if let remove {
                    pdfView?.removeOverlayImage(id: remove.id)
                }
            case .overlayImageUpdate(_, let after):
                pdfView?.updateOverlayImage(from: after)
            case .deleteInkAnnotation(let ann, let page):
                page.removeAnnotation(ann)
                if pdfView?.selectedInkAnnotation === ann {
                    pdfView?.deselectInkAnnotation()
                }
            case .overlayShape(let add, let remove):
                if let add { pdfView?.addOverlayShape(from: add) }
                if let remove { pdfView?.removeOverlayShape(id: remove.id) }
            case .overlayShapeUpdate(_, let after):
                pdfView?.updateOverlayShape(from: after)
            case .addPage(let page, let at):
                guard let document = pdfDocument else { return }
                let safeIndex = max(0, min(at, document.pageCount))
                document.insert(page, at: safeIndex)
                updatePageMetrics()
                goToPage(index: safeIndex)
            case .removePage(_, let at):
                guard let document = pdfDocument else { return }
                guard at < document.pageCount else { return }
                document.removePage(at: at)
                updatePageMetrics()
                goToPage(index: max(0, at - 1))
            }
        }

    private func applyFormFieldValue(annotation: PDFAnnotation, value: String?) {
        pdfView?.beginApplyingFormUndoRedo()
        defer { pdfView?.endApplyingFormUndoRedo() }
        annotation.widgetStringValue = value
        annotation.setValue(value as Any, forAnnotationKey: .widgetValue)
        // Keep /AS in sync for button widgets so PDF renderers select the correct
        // appearance stream when the document is written or flattened.
        // For radio button groups, sync every member of the group so that deselected
        // siblings all carry /AS = "Off" rather than a stale on-state value.
        if annotation.widgetFieldType == .button {
            annotation.setValue(value as Any, forAnnotationKey: PDFAnnotationKey(rawValue: "/AS"))
            if let fieldName = annotation.fieldName {
                pdfView?.syncButtonGroupAppearanceStates(fieldName: fieldName)
            }
        }
        pdfView?.syncFormFieldBaseline(for: annotation)
        pdfView?.refreshFormWidgetAppearance(for: annotation)
        pdfView?.refreshAllFormWidgetAppearances()
        pdfView?.scheduleFullFormWidgetAppearanceRefresh()
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

    @discardableResult
    func savePDF() -> URL? {
        guard pdfDocument != nil else { return nil }

        // Commit any in-progress form field edit so PDFKit generates a current
        // appearance stream before writing. Without this, a field that is still
        // focused when Save is tapped may have a stale or absent appearance stream,
        // causing PDFKit to set /NeedAppearances true in the AcroForm dictionary.
        pdfView?.commitActiveFormWidgetTextToAnnotations()
        pdfView?.endEditing(true)

        // Write real PDF annotations into a copy of the displayed document so
        // third-party readers can see overlays without polluting PDFKit's live
        // editor render cache with temporary stamp appearances.
        guard let editableDocument = pdfView?.editableExportDocumentCopy() else {
            saveStatus = "Failed to save PDF"
            return nil
        }

        let fileName = defaultFileName(for: .editable)
        let stagingURL = stagingURL(fileName: fileName)
        try? FileManager.default.createDirectory(
            at: stagingURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )

        guard editableDocument.write(to: stagingURL) else {
            saveStatus = "Failed to save PDF"
            return nil
        }

        do {
            let finalURL = try finalizeGeneratedFile(
                at: stagingURL,
                request: PDFEditorFileRequest(
                    kind: .editable,
                    sourceURL: currentDocumentURL,
                    temporaryURL: stagingURL,
                    suggestedFileName: fileName
                ),
                handler: editableSaveHandler
            )
            currentDocumentURL = finalURL
            lastSavedURL = finalURL
            saveStatus = "Saved to: \(finalURL.lastPathComponent)"
            return finalURL
        } catch {
            saveStatus = "Failed to save PDF"
            return nil
        }
    }
    
    /// Exports the document in its editable form for sharing.
    ///
    /// Always writes to a fresh temp URL so the system share sheet can read the
    /// file regardless of where the host app's save handler would normally put it.
    /// Does not modify currentDocumentURL / lastSavedURL.
    func exportEditablePDF() -> URL? {
        guard pdfDocument != nil else {
            exportStatus = "Failed to export PDF"
            return nil
        }

        pdfView?.commitActiveFormWidgetTextToAnnotations()
        pdfView?.endEditing(true)

        guard let editableDocument = pdfView?.editableExportDocumentCopy() else {
            exportStatus = "Failed to export PDF"
            return nil
        }

        let fileName = defaultFileName(for: .editable)
        let tempURL = stagingURL(fileName: fileName)
        try? FileManager.default.createDirectory(
            at: tempURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )

        guard editableDocument.write(to: tempURL) else {
            exportStatus = "Failed to export PDF"
            return nil
        }
        exportStatus = "Ready to share"
        return tempURL
    }

    func exportFlattenedPDF() -> URL? {
        guard let document = pdfDocument else {
            exportStatus = "No overlays to export"
            return nil
        }

        // Copy any in-progress PDF widget text into annotations while the hosted
        // control still reflects the keyboard; PDFKit may not update widgetStringValue
        // synchronously when we only call endEditing.
        pdfView?.commitActiveFormWidgetTextToAnnotations()
        // Share can begin before keyboard notifications run; flush undo tracking now
        // so the latest field edit is always represented in undo/redo history.
        pdfView?.flushPendingFormFieldUndoTracking()
        // Resign any active text editor (native PDF form field or overlay text box)
        // so PDFKit commits the in-progress value and regenerates the annotation
        // appearance stream before we render. Without this, the field appears blank
        // on the first share and only shows on subsequent shares (after the share
        // sheet presentation naturally steals focus and causes a commit).
        pdfView?.endEditing(true)

        guard let metadata = pdfView?.overlayMetadataSnapshot() else {
            exportStatus = "No overlays to export"
            return nil
        }

        let fileName = defaultFileName(for: .flattened)
        let stagingURL = stagingURL(fileName: fileName)
        try? FileManager.default.createDirectory(
            at: stagingURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )

        guard renderFlattenedPDF(document: document, metadata: metadata, destinationURL: stagingURL) else {
            exportStatus = "Failed to export PDF"
            return nil
        }

        do {
            let finalURL = try finalizeGeneratedFile(
                at: stagingURL,
                request: PDFEditorFileRequest(
                    kind: .flattened,
                    sourceURL: currentDocumentURL,
                    temporaryURL: stagingURL,
                    suggestedFileName: fileName
                ),
                handler: flattenedExportHandler
            )
            exportStatus = "Exported to: \(finalURL.lastPathComponent)"
            return finalURL
        } catch {
            exportStatus = "Failed to export PDF"
            return nil
        }
    }
    
    private func renderFlattenedPDF(
        document: PDFDocument,
        metadata: OverlayDocumentMetadata,
        destinationURL: URL
    ) -> Bool {
        guard document.pageCount > 0 else { return false }
        let firstBounds = document.page(at: 0)?.bounds(for: .mediaBox) ?? CGRect(x: 0, y: 0, width: 612, height: 792)
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = PDFOverlayRenderer.pdfDocumentInfo(from: document)
        let renderer = UIGraphicsPDFRenderer(bounds: firstBounds, format: format)
        do {
            try renderer.writePDF(to: destinationURL) { context in
                for pageIndex in 0..<document.pageCount {
                    guard let page = document.page(at: pageIndex) else { continue }
                    let bounds = page.bounds(for: .mediaBox)
                    context.beginPage(withBounds: bounds, pageInfo: [:])
                    PDFOverlayRenderer.renderPage(page, pageIndex: pageIndex, metadata: metadata,
                                                  into: context.cgContext, bounds: bounds)
                }
            }
            return true
        } catch {
            return false
        }
    }
    
    private func defaultFileName(for kind: PDFEditorDocumentKind) -> String {
        let baseName = currentDocumentURL?.deletingPathExtension().lastPathComponent ?? "Document"
        switch kind {
        case .editable:
            return "\(baseName)-Editable.pdf"
        case .flattened:
            return "\(baseName)-Flattened.pdf"
        }
    }

    private func stagingURL(fileName: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent(fileName)
    }

    private func finalizeGeneratedFile(
        at generatedURL: URL,
        request: PDFEditorFileRequest,
        handler: PDFEditorFileHandler?
    ) throws -> URL {
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: generatedURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )

        if let handler {
            let finalURL = try handler(request)
            if finalURL != generatedURL, fileManager.fileExists(atPath: generatedURL.path) {
                try? fileManager.removeItem(at: generatedURL)
            }
            return finalURL
        }

        let folderURL = defaultFolderURL(for: request.kind)
        try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
        let destinationURL = uniqueDestinationURL(
            for: request.suggestedFileName,
            in: folderURL
        )
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.moveItem(at: generatedURL, to: destinationURL)
        return destinationURL
    }

    private func defaultFolderURL(for kind: PDFEditorDocumentKind) -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        switch kind {
        case .editable:
            return documentsPath.appendingPathComponent("PDFEdits", isDirectory: true)
        case .flattened:
            return documentsPath.appendingPathComponent("PDFExports", isDirectory: true)
        }
    }

    private func uniqueDestinationURL(for fileName: String, in folderURL: URL) -> URL {
        let baseName = URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
        let ext = URL(fileURLWithPath: fileName).pathExtension.isEmpty ? "pdf" : URL(fileURLWithPath: fileName).pathExtension
        var candidate = folderURL.appendingPathComponent("\(baseName).\(ext)")
        var counter = 1
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folderURL.appendingPathComponent("\(baseName)-\(counter).\(ext)")
            counter += 1
        }
        return candidate
    }

}

// MARK: - PencilGestureHandler Conformance
extension PDFFormViewModel: PencilGestureHandler {}
