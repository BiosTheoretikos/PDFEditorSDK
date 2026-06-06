import CoreGraphics
import Foundation
import PDFKit
import Testing
import UIKit
@testable import PDFEditor

struct PDFEditorSDKUtilityTests {
    @Test
    @MainActor
    func thumbnailRejectsInvalidRenderSizeBeforeLoadingDocument() throws {
        let missingURL = URL(fileURLWithPath: "/tmp/missing-\(UUID().uuidString).pdf")

        PDFEditorTestSupport.expectPDFEditorError({
            if case .invalidRenderSize(let size) = $0 {
                return size == .zero
            }
            return false
        }) {
            try PDFEditorSDK.thumbnail(for: missingURL, size: .zero)
        }
    }

    @Test
    @MainActor
    func thumbnailRejectsMissingDocument() throws {
        let missingURL = URL(fileURLWithPath: "/tmp/missing-\(UUID().uuidString).pdf")

        PDFEditorTestSupport.expectPDFEditorError({
            if case .documentLoadFailed(let url) = $0 {
                return url == missingURL
            }
            return false
        }) {
            try PDFEditorSDK.thumbnail(for: missingURL, size: CGSize(width: 120, height: 120))
        }
    }

    @Test
    @MainActor
    func thumbnailRejectsMissingPage() throws {
        let pdfURL = try PDFEditorTestSupport.makeTemporaryPDFURL(pageCount: 1)
        defer { try? FileManager.default.removeItem(at: pdfURL.deletingLastPathComponent()) }

        PDFEditorTestSupport.expectPDFEditorError({
            if case .pageNotFound(let index) = $0 {
                return index == 2
            }
            return false
        }) {
            try PDFEditorSDK.thumbnail(
                for: pdfURL,
                pageIndex: 2,
                size: CGSize(width: 120, height: 120)
            )
        }
    }

    @Test
    @MainActor
    func thumbnailRendersAspectFitPageImage() throws {
        let pdfURL = try PDFEditorTestSupport.makeTemporaryPDFURL(
            pageSize: CGSize(width: 200, height: 100)
        )
        defer { try? FileManager.default.removeItem(at: pdfURL.deletingLastPathComponent()) }

        let image = try PDFEditorSDK.thumbnail(
            for: pdfURL,
            size: CGSize(width: 100, height: 100)
        )

        #expect(abs(image.size.width - 100) < 0.01)
        #expect(abs(image.size.height - 50) < 0.01)
    }

    @Test
    @MainActor
    func flattenedPDFRejectsMissingDocument() throws {
        let missingURL = URL(fileURLWithPath: "/tmp/missing-\(UUID().uuidString).pdf")

        PDFEditorTestSupport.expectPDFEditorError({
            if case .documentLoadFailed(let url) = $0 {
                return url == missingURL
            }
            return false
        }) {
            try PDFEditorSDK.flattenedPDF(from: missingURL)
        }
    }

    @Test
    @MainActor
    func flattenedPDFWritesValidTemporaryPDF() throws {
        let pdfURL = try PDFEditorTestSupport.makeTemporaryPDFURL(
            fileName: "Contract.pdf",
            pageCount: 2
        )
        defer { try? FileManager.default.removeItem(at: pdfURL.deletingLastPathComponent()) }

        let flattenedURL = try PDFEditorSDK.flattenedPDF(from: pdfURL)
        defer { try? FileManager.default.removeItem(at: flattenedURL.deletingLastPathComponent()) }
        let flattenedDocument = try #require(PDFDocument(url: flattenedURL))

        #expect(FileManager.default.fileExists(atPath: flattenedURL.path))
        #expect(flattenedURL.lastPathComponent == "Contract-Flattened.pdf")
        #expect(flattenedDocument.pageCount == 2)
    }
}
