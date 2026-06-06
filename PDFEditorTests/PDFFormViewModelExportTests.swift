import Foundation
import PDFKit
import Testing
@testable import PDFEditor

struct PDFFormViewModelExportTests {
    @Test
    @MainActor
    func saveWithoutLoadedDocumentThrowsAndUpdatesStatus() {
        PDFEditorTestSupport.withPreservedEditorPreferences {
            let viewModel = PDFFormViewModel(
                documentURL: URL(fileURLWithPath: "/tmp/missing-\(UUID().uuidString).pdf")
            )

            do {
                _ = try viewModel.savePDF()
                Issue.record("Expected documentNotLoaded.")
            } catch let error as PDFEditorError {
                if case .documentNotLoaded = error {
                    #expect(viewModel.saveStatus == "No PDF document is loaded.")
                } else {
                    Issue.record("Unexpected PDFEditorError: \(error)")
                }
            } catch {
                Issue.record("Unexpected error type: \(error)")
            }
        }
    }

    @Test
    @MainActor
    func exportEditableWithoutLoadedDocumentThrowsAndUpdatesStatus() {
        PDFEditorTestSupport.withPreservedEditorPreferences {
            let viewModel = PDFFormViewModel(
                documentURL: URL(fileURLWithPath: "/tmp/missing-\(UUID().uuidString).pdf")
            )

            do {
                _ = try viewModel.exportEditablePDF()
                Issue.record("Expected documentNotLoaded.")
            } catch let error as PDFEditorError {
                if case .documentNotLoaded = error {
                    #expect(viewModel.exportStatus == "No PDF document is loaded.")
                } else {
                    Issue.record("Unexpected PDFEditorError: \(error)")
                }
            } catch {
                Issue.record("Unexpected error type: \(error)")
            }
        }
    }

    @Test
    @MainActor
    func exportFlattenedWithoutLoadedDocumentThrowsAndUpdatesStatus() {
        PDFEditorTestSupport.withPreservedEditorPreferences {
            let viewModel = PDFFormViewModel(
                documentURL: URL(fileURLWithPath: "/tmp/missing-\(UUID().uuidString).pdf")
            )

            do {
                _ = try viewModel.exportFlattenedPDF()
                Issue.record("Expected documentNotLoaded.")
            } catch let error as PDFEditorError {
                if case .documentNotLoaded = error {
                    #expect(viewModel.exportStatus == "No PDF document is loaded.")
                } else {
                    Issue.record("Unexpected PDFEditorError: \(error)")
                }
            } catch {
                Issue.record("Unexpected error type: \(error)")
            }
        }
    }

    @Test
    @MainActor
    func exportEditableWithLoadedDocumentRequiresEditableExportCopy() throws {
        try PDFEditorTestSupport.withPreservedEditorPreferences {
            let viewModel = try makeLoadedViewModel()

            do {
                _ = try viewModel.exportEditablePDF()
                Issue.record("Expected exportDocumentUnavailable.")
            } catch let error as PDFEditorError {
                if case .exportDocumentUnavailable = error {
                    #expect(viewModel.exportStatus == "Could not create an editable export copy of the PDF.")
                } else {
                    Issue.record("Unexpected PDFEditorError: \(error)")
                }
            } catch {
                Issue.record("Unexpected error type: \(error)")
            }
        }
    }

    @Test
    @MainActor
    func exportFlattenedWithLoadedDocumentRequiresOverlayMetadataSnapshot() throws {
        try PDFEditorTestSupport.withPreservedEditorPreferences {
            let viewModel = try makeLoadedViewModel()

            do {
                _ = try viewModel.exportFlattenedPDF()
                Issue.record("Expected overlayMetadataUnavailable.")
            } catch let error as PDFEditorError {
                if case .overlayMetadataUnavailable = error {
                    #expect(viewModel.exportStatus == "Could not read the PDF overlay metadata.")
                } else {
                    Issue.record("Unexpected PDFEditorError: \(error)")
                }
            } catch {
                Issue.record("Unexpected error type: \(error)")
            }
        }
    }

    @Test
    @MainActor
    func renderFlattenedPDFRejectsEmptyDocuments() throws {
        try PDFEditorTestSupport.withPreservedEditorPreferences {
            let viewModel = try makeLoadedViewModel()
            let directory = try PDFEditorTestSupport.makeTemporaryDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let destinationURL = directory.appendingPathComponent("Flattened.pdf")

            do {
                try viewModel.renderFlattenedPDF(
                    document: PDFDocument(),
                    metadata: OverlayDocumentMetadata(),
                    destinationURL: destinationURL
                )
                Issue.record("Expected emptyDocument.")
            } catch let error as PDFEditorError {
                if case .emptyDocument = error {
                    #expect(viewModel.exportStatus == "PDF document has no pages.")
                } else {
                    Issue.record("Unexpected PDFEditorError: \(error)")
                }
            } catch {
                Issue.record("Unexpected error type: \(error)")
            }
        }
    }

    @Test
    @MainActor
    func renderFlattenedPDFWritesValidPDF() throws {
        try PDFEditorTestSupport.withPreservedEditorPreferences {
            let viewModel = try makeLoadedViewModel()
            let document = try PDFEditorTestSupport.makePDFDocument(pageCount: 2)
            let directory = try PDFEditorTestSupport.makeTemporaryDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let destinationURL = directory.appendingPathComponent("Flattened.pdf")

            try viewModel.renderFlattenedPDF(
                document: document,
                metadata: OverlayDocumentMetadata(),
                destinationURL: destinationURL
            )
            let flattenedDocument = try #require(PDFDocument(url: destinationURL))

            #expect(FileManager.default.fileExists(atPath: destinationURL.path))
            #expect(flattenedDocument.pageCount == 2)
            #expect(viewModel.exportStatus == nil)
        }
    }

    @MainActor
    private func makeLoadedViewModel() throws -> PDFFormViewModel {
        let document = PDFEditorDocument(
            pdfDocument: try PDFEditorTestSupport.makePDFDocument()
        )
        return PDFFormViewModel(document: document)
    }
}
