import Foundation

enum PDFGeneratedFileStore {
    static func defaultFileName(for kind: PDFEditorDocumentKind, sourceURL: URL?) -> String {
        let baseName = sourceURL?.deletingPathExtension().lastPathComponent ?? "Document"
        switch kind {
        case .editable:
            return "\(baseName)-Editable.pdf"
        case .flattened:
            return "\(baseName)-Flattened.pdf"
        }
    }

    static func stagingURL(fileName: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent(fileName)
    }

    static func prepareStagingURL(fileName: String) throws -> URL {
        let url = stagingURL(fileName: fileName)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        return url
    }

    static func finalize(
        generatedURL: URL,
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
                try fileManager.removeItem(at: generatedURL)
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

    private static func defaultFolderURL(for kind: PDFEditorDocumentKind) -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        switch kind {
        case .editable:
            return documentsPath.appendingPathComponent("PDFEdits", isDirectory: true)
        case .flattened:
            return documentsPath.appendingPathComponent("PDFExports", isDirectory: true)
        }
    }

    private static func uniqueDestinationURL(for fileName: String, in folderURL: URL) -> URL {
        let url = URL(fileURLWithPath: fileName)
        let baseName = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension.isEmpty ? "pdf" : url.pathExtension
        var candidate = folderURL.appendingPathComponent("\(baseName).\(ext)")
        var counter = 1
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folderURL.appendingPathComponent("\(baseName)-\(counter).\(ext)")
            counter += 1
        }
        return candidate
    }
}
