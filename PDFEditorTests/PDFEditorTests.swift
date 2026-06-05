import CoreGraphics
import Foundation
import Testing
@testable import PDFEditor

struct PDFEditorTests {
    @Test func thumbnailRejectsInvalidRenderSizeBeforeLoadingDocument() async throws {
        let missingURL = URL(fileURLWithPath: "/tmp/missing-\(UUID().uuidString).pdf")

        do {
            _ = try PDFEditorSDK.thumbnail(for: missingURL, size: .zero)
            Issue.record("Expected invalidRenderSize to be thrown.")
        } catch let error as PDFEditorError {
            if case .invalidRenderSize(let size) = error {
                #expect(size == .zero)
            } else {
                Issue.record("Unexpected PDFEditorError: \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test func defaultFileNamesDescribeDocumentKind() {
        let sourceURL = URL(fileURLWithPath: "/tmp/Contract.pdf")

        #expect(PDFGeneratedFileStore.defaultFileName(for: .editable, sourceURL: sourceURL) == "Contract-Editable.pdf")
        #expect(PDFGeneratedFileStore.defaultFileName(for: .flattened, sourceURL: sourceURL) == "Contract-Flattened.pdf")
    }

    @Test func generatedFileStoreFinalizesIntoDefaultFolder() throws {
        let fileName = "UnitTest-\(UUID().uuidString).pdf"
        let stagingURL = try PDFGeneratedFileStore.prepareStagingURL(fileName: fileName)
        try Data("%PDF-1.4\n%EOF\n".utf8).write(to: stagingURL)

        let finalURL = try PDFGeneratedFileStore.finalize(
            generatedURL: stagingURL,
            request: PDFEditorFileRequest(
                kind: .editable,
                sourceURL: nil,
                temporaryURL: stagingURL,
                suggestedFileName: fileName
            ),
            handler: nil
        )
        defer { try? FileManager.default.removeItem(at: finalURL) }

        #expect(FileManager.default.fileExists(atPath: finalURL.path))
        #expect(finalURL.lastPathComponent == fileName)
    }
}
