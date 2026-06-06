import Foundation
import PDFKit
import Testing
import UniformTypeIdentifiers
@testable import PDFEditor

struct PDFEditorDocumentTests {
    @Test
    @MainActor
    func advertisedContentTypesArePDFOnly() {
        #expect(PDFEditorDocument.readableContentTypes == [.pdf])
        #expect(PDFEditorDocument.writableContentTypes == [.pdf])
    }

    @Test
    @MainActor
    func snapshotContainsCurrentPDFData() throws {
        let pdfDocument = try PDFEditorTestSupport.makePDFDocument(pageCount: 2)
        let document = PDFEditorDocument(pdfDocument: pdfDocument)

        let snapshot = try document.snapshot(contentType: .pdf)
        let restored = try #require(PDFDocument(data: snapshot.data))

        #expect(restored.pageCount == 2)
    }

    @Test
    @MainActor
    func makePDFDocumentCopyDoesNotExposeStoredDocumentForMutation() throws {
        let pdfDocument = try PDFEditorTestSupport.makePDFDocument(pageCount: 2)
        let document = PDFEditorDocument(pdfDocument: pdfDocument)

        let copy = try document.makePDFDocumentCopy()
        copy.removePage(at: 0)

        let storedPageCount = document.withPDFDocument { storedDocument in
            storedDocument.pageCount
        }

        #expect(copy.pageCount == 1)
        #expect(storedPageCount == 2)
    }

    @Test
    @MainActor
    func replacingDocumentUpdatesFutureSnapshots() throws {
        let original = try PDFEditorTestSupport.makePDFDocument(pageCount: 1)
        let replacement = try PDFEditorTestSupport.makePDFDocument(pageCount: 3)
        let document = PDFEditorDocument(pdfDocument: original)

        document.replacePDFDocument(replacement)
        let snapshot = try document.snapshot(contentType: .pdf)
        let restored = try #require(PDFDocument(data: snapshot.data))

        #expect(restored.pageCount == 3)
    }

    @Test
    @MainActor
    func replacingDocumentWithInvalidDataThrowsCorruptFileError() throws {
        let document = PDFEditorDocument(pdfDocument: try PDFEditorTestSupport.makePDFDocument())

        do {
            try document.replacePDFDocument(with: Data("not a pdf".utf8))
            Issue.record("Expected corrupt file error.")
        } catch let error as CocoaError {
            #expect(error.code == .fileReadCorruptFile)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
}
