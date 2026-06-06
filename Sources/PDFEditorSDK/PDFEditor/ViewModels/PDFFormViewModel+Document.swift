//
//  PDFFormViewModel+Document.swift
//  PDFEditorSDK
//

import Foundation
import PDFKit
import UIKit

@MainActor
extension PDFFormViewModel {
    @discardableResult
    func loadPDF(from url: URL) -> Bool {
        guard let document = PDFDocument(url: url) else {
            openStatus = "Failed to open PDF"
            return false
        }
        return loadPDF(document, sourceURL: url)
    }

    @discardableResult
    func loadPDF(from document: PDFEditorDocument) -> Bool {
        do {
            let pdfDocument = try document.makePDFDocumentCopy()
            return loadPDF(pdfDocument, sourceURL: nil)
        } catch {
            openStatus = error.localizedDescription
            return false
        }
    }

    @discardableResult
    private func loadPDF(_ document: PDFDocument, sourceURL: URL?) -> Bool {
        currentDocumentURL = sourceURL
        pendingOverlayMetadata = extractRealOverlayMetadata(from: document)
        pdfDocument = document
        didLoadOverlayMetadata = false
        needsOverlayRestore = true
        updatePageMetrics()
        return true
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

    func extractRealOverlayMetadata(from document: PDFDocument) -> OverlayDocumentMetadata? {
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
}
