//
//  PDFFormViewModel+UndoRedo.swift
//  PDFEditorSDK
//

import SwiftUI
import PDFKit
import UIKit

@MainActor
extension PDFFormViewModel {
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

    func prepareForFormUndoRedo() {
        guard let pdfView else { return }
        pdfView.commitActiveFormWidgetTextToAnnotations()
        pdfView.flushPendingFormFieldUndoTracking()
        pdfView.endEditing(true)
    }

    func resolveOverlayStateIfNeeded(_ action: UndoAction) -> UndoAction {
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
    
    func performUndoAction(_ action: UndoAction) {
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

    func performRedoAction(_ action: UndoAction) {
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

    func applyFormFieldValue(annotation: PDFAnnotation, value: String?) {
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
}
