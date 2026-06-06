import CoreGraphics
import Foundation
import Testing
@testable import PDFEditor

struct PDFEditorErrorTests {
    @Test func descriptionsIncludeRelevantContext() {
        let url = URL(fileURLWithPath: "/tmp/Contract.pdf")

        #expect(PDFEditorError.documentLoadFailed(url).errorDescription == "Failed to load PDF at Contract.pdf.")
        #expect(PDFEditorError.documentNotLoaded.errorDescription == "No PDF document is loaded.")
        #expect(PDFEditorError.emptyDocument(url).errorDescription == "PDF at Contract.pdf has no pages.")
        #expect(PDFEditorError.emptyDocument(nil).errorDescription == "PDF document has no pages.")
        #expect(PDFEditorError.pageNotFound(index: 3).errorDescription == "PDF page 3 was not found.")
        #expect(PDFEditorError.invalidRenderSize(CGSize(width: 0, height: -4)).errorDescription == "Invalid render size 0 x -4.")
        #expect(PDFEditorError.exportDocumentUnavailable.errorDescription == "Could not create an editable export copy of the PDF.")
        #expect(PDFEditorError.overlayMetadataUnavailable.errorDescription == "Could not read the PDF overlay metadata.")
        #expect(PDFEditorError.documentWriteFailed(url).errorDescription == "Failed to write PDF to Contract.pdf.")
        #expect(PDFEditorError.flattenedRenderFailed(url).errorDescription == "Failed to render flattened PDF to Contract.pdf.")
        #expect(PDFEditorError.generatedFileFinalizationFailed("Disk full").errorDescription == "Failed to finalize generated PDF: Disk full")
    }
}
