//
//  PDFFormViewModel+Export.swift
//  PDFEditorSDK
//

import Foundation
import PDFKit
import UIKit

@MainActor
extension PDFFormViewModel {
    @discardableResult
    func savePDF() throws -> URL {
        guard pdfDocument != nil else {
            let error = PDFEditorError.documentNotLoaded
            saveStatus = error.localizedDescription
            throw error
        }

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
            let error = PDFEditorError.exportDocumentUnavailable
            saveStatus = error.localizedDescription
            throw error
        }

        let fileName = PDFGeneratedFileStore.defaultFileName(for: .editable, sourceURL: currentDocumentURL)
        let stagingURL = try PDFGeneratedFileStore.prepareStagingURL(fileName: fileName)

        guard editableDocument.write(to: stagingURL) else {
            let error = PDFEditorError.documentWriteFailed(stagingURL)
            saveStatus = error.localizedDescription
            throw error
        }

        do {
            let finalURL = try PDFGeneratedFileStore.finalize(
                generatedURL: stagingURL,
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
            let wrappedError = PDFEditorError.generatedFileFinalizationFailed(error.localizedDescription)
            saveStatus = wrappedError.localizedDescription
            throw wrappedError
        }
    }

    /// Exports the document in its editable form for sharing.
    ///
    /// Always writes to a fresh temp URL so the system share sheet can read the
    /// file regardless of where the host app's save handler would normally put it.
    /// Does not modify currentDocumentURL / lastSavedURL.
    func exportEditablePDF() throws -> URL {
        guard pdfDocument != nil else {
            let error = PDFEditorError.documentNotLoaded
            exportStatus = error.localizedDescription
            throw error
        }

        pdfView?.commitActiveFormWidgetTextToAnnotations()
        pdfView?.endEditing(true)

        guard let editableDocument = pdfView?.editableExportDocumentCopy() else {
            let error = PDFEditorError.exportDocumentUnavailable
            exportStatus = error.localizedDescription
            throw error
        }

        let fileName = PDFGeneratedFileStore.defaultFileName(for: .editable, sourceURL: currentDocumentURL)
        let tempURL = try PDFGeneratedFileStore.prepareStagingURL(fileName: fileName)

        guard editableDocument.write(to: tempURL) else {
            let error = PDFEditorError.documentWriteFailed(tempURL)
            exportStatus = error.localizedDescription
            throw error
        }
        exportStatus = "Ready to share"
        return tempURL
    }

    func exportFlattenedPDF() throws -> URL {
        guard let document = pdfDocument else {
            let error = PDFEditorError.documentNotLoaded
            exportStatus = error.localizedDescription
            throw error
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
            let error = PDFEditorError.overlayMetadataUnavailable
            exportStatus = error.localizedDescription
            throw error
        }

        let fileName = PDFGeneratedFileStore.defaultFileName(for: .flattened, sourceURL: currentDocumentURL)
        let stagingURL = try PDFGeneratedFileStore.prepareStagingURL(fileName: fileName)

        try renderFlattenedPDF(document: document, metadata: metadata, destinationURL: stagingURL)

        do {
            let finalURL = try PDFGeneratedFileStore.finalize(
                generatedURL: stagingURL,
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
            let wrappedError = PDFEditorError.generatedFileFinalizationFailed(error.localizedDescription)
            exportStatus = wrappedError.localizedDescription
            throw wrappedError
        }
    }

    func renderFlattenedPDF(
        document: PDFDocument,
        metadata: OverlayDocumentMetadata,
        destinationURL: URL
    ) throws {
        guard document.pageCount > 0 else {
            let error = PDFEditorError.emptyDocument(currentDocumentURL)
            exportStatus = error.localizedDescription
            throw error
        }
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
        } catch {
            let error = PDFEditorError.flattenedRenderFailed(destinationURL)
            exportStatus = error.localizedDescription
            throw error
        }
    }
}
