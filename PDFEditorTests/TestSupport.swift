import CoreGraphics
import Foundation
import PDFKit
import Testing
import UIKit
@testable import PDFEditor

enum PDFEditorTestSupport {
    static let defaultPageSize = CGSize(width: 200, height: 240)

    static func makePDFData(
        pageCount: Int = 1,
        pageSize: CGSize = defaultPageSize
    ) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        return renderer.pdfData { context in
            for pageIndex in 0..<pageCount {
                context.beginPage()
                UIColor.white.setFill()
                context.fill(CGRect(origin: .zero, size: pageSize))

                let text = "Page \(pageIndex + 1)"
                text.draw(
                    at: CGPoint(x: 20, y: 20),
                    withAttributes: [
                        .font: UIFont.systemFont(ofSize: 16),
                        .foregroundColor: UIColor.black
                    ]
                )
            }
        }
    }

    static func makePDFDocument(
        pageCount: Int = 1,
        pageSize: CGSize = defaultPageSize
    ) throws -> PDFDocument {
        let data = makePDFData(pageCount: pageCount, pageSize: pageSize)
        guard let document = PDFDocument(data: data) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return document
    }

    static func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PDFEditorTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func makeTemporaryPDFURL(
        fileName: String = "Document.pdf",
        pageCount: Int = 1,
        pageSize: CGSize = defaultPageSize
    ) throws -> URL {
        let directory = try makeTemporaryDirectory()
        let url = directory.appendingPathComponent(fileName)
        try makePDFData(pageCount: pageCount, pageSize: pageSize).write(to: url)
        return url
    }

    static func makePNGBase64(
        color: UIColor = .systemGreen,
        size: CGSize = CGSize(width: 16, height: 16)
    ) throws -> String {
        let image = UIGraphicsImageRenderer(size: size).image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        guard let data = image.pngData() else {
            throw CocoaError(.fileWriteUnknown)
        }
        return data.base64EncodedString()
    }

    static func expectPDFEditorError<T>(
        _ expected: (PDFEditorError) -> Bool,
        _ body: () throws -> T
    ) {
        do {
            _ = try body()
            Issue.record("Expected PDFEditorError to be thrown.")
        } catch let error as PDFEditorError {
            #expect(expected(error))
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
}
