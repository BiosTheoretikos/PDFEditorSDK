import Foundation
import Testing
@testable import PDFEditor

struct PDFGeneratedFileStoreTests {
    @Test func defaultFileNamesDescribeDocumentKindAndSource() {
        let sourceURL = URL(fileURLWithPath: "/tmp/Contract.pdf")

        #expect(PDFGeneratedFileStore.defaultFileName(for: .editable, sourceURL: sourceURL) == "Contract-Editable.pdf")
        #expect(PDFGeneratedFileStore.defaultFileName(for: .flattened, sourceURL: sourceURL) == "Contract-Flattened.pdf")
        #expect(PDFGeneratedFileStore.defaultFileName(for: .editable, sourceURL: nil) == "Document-Editable.pdf")
        #expect(PDFGeneratedFileStore.defaultFileName(for: .flattened, sourceURL: nil) == "Document-Flattened.pdf")
    }

    @Test func prepareStagingURLCreatesUniqueParentDirectories() throws {
        let firstURL = try PDFGeneratedFileStore.prepareStagingURL(fileName: "Document.pdf")
        let secondURL = try PDFGeneratedFileStore.prepareStagingURL(fileName: "Document.pdf")
        defer {
            try? FileManager.default.removeItem(at: firstURL.deletingLastPathComponent())
            try? FileManager.default.removeItem(at: secondURL.deletingLastPathComponent())
        }

        #expect(firstURL != secondURL)
        #expect(firstURL.lastPathComponent == "Document.pdf")
        #expect(secondURL.lastPathComponent == "Document.pdf")
        #expect(FileManager.default.fileExists(atPath: firstURL.deletingLastPathComponent().path))
        #expect(FileManager.default.fileExists(atPath: secondURL.deletingLastPathComponent().path))
    }

    @Test func finalizeWithDefaultFolderMovesStagingFile() throws {
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
        #expect(!FileManager.default.fileExists(atPath: stagingURL.path))
        #expect(finalURL.lastPathComponent == fileName)
    }

    @Test func finalizeWithDefaultFolderAvoidsOverwritingExistingFiles() throws {
        let fileName = "UnitTest-\(UUID().uuidString).pdf"
        let firstURL = try makeDefaultFinalizedFile(fileName: fileName, contents: "first")
        let secondURL = try makeDefaultFinalizedFile(fileName: fileName, contents: "second")
        defer {
            try? FileManager.default.removeItem(at: firstURL)
            try? FileManager.default.removeItem(at: secondURL)
        }

        #expect(firstURL.lastPathComponent == fileName)
        #expect(secondURL.lastPathComponent == fileName.replacingOccurrences(of: ".pdf", with: "-1.pdf"))
        #expect(try String(contentsOf: firstURL, encoding: .utf8) == "first")
        #expect(try String(contentsOf: secondURL, encoding: .utf8) == "second")
    }

    @Test func finalizeWithHandlerReturnsHandlerURLAndRemovesStagingFile() throws {
        let stagingURL = try PDFGeneratedFileStore.prepareStagingURL(fileName: "Handled.pdf")
        let destinationDirectory = try PDFEditorTestSupport.makeTemporaryDirectory()
        let destinationURL = destinationDirectory.appendingPathComponent("Final.pdf")
        defer {
            try? FileManager.default.removeItem(at: stagingURL.deletingLastPathComponent())
            try? FileManager.default.removeItem(at: destinationDirectory)
        }
        try Data("handled".utf8).write(to: stagingURL)

        let finalURL = try PDFGeneratedFileStore.finalize(
            generatedURL: stagingURL,
            request: PDFEditorFileRequest(
                kind: .flattened,
                sourceURL: URL(fileURLWithPath: "/tmp/Source.pdf"),
                temporaryURL: stagingURL,
                suggestedFileName: "Handled.pdf"
            ),
            handler: { request in
                switch request.kind {
                case .editable:
                    Issue.record("Expected flattened file request.")
                case .flattened:
                    break
                }
                #expect(request.temporaryURL == stagingURL)
                #expect(request.suggestedFileName == "Handled.pdf")
                try FileManager.default.copyItem(at: request.temporaryURL, to: destinationURL)
                return destinationURL
            }
        )

        #expect(finalURL == destinationURL)
        #expect(FileManager.default.fileExists(atPath: destinationURL.path))
        #expect(!FileManager.default.fileExists(atPath: stagingURL.path))
    }

    private func makeDefaultFinalizedFile(fileName: String, contents: String) throws -> URL {
        let stagingURL = try PDFGeneratedFileStore.prepareStagingURL(fileName: fileName)
        try Data(contents.utf8).write(to: stagingURL)
        return try PDFGeneratedFileStore.finalize(
            generatedURL: stagingURL,
            request: PDFEditorFileRequest(
                kind: .editable,
                sourceURL: nil,
                temporaryURL: stagingURL,
                suggestedFileName: fileName
            ),
            handler: nil
        )
    }
}
