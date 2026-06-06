//
//  PDFAnnotatorDocument.swift
//  PDFEditorSDK
//
//  Created by Brian Eggleston on 5/19/26.
//

@preconcurrency import Combine
@preconcurrency import PDFKit
import Synchronization
import SwiftUI
import UniformTypeIdentifiers

public final class PDFAnnotatorDocument: ReferenceFileDocument, ObservableObject, @unchecked Sendable {

    public let objectWillChange = ObservableObjectPublisher()
    private let protectedPDFDocument: Mutex<PDFDocument>

    public init(pdfDocument: sending PDFDocument = PDFDocument()) {
        self.protectedPDFDocument = .init(pdfDocument)
    }

    @MainActor
    public func withPDFDocument<R: Sendable>(
        _ body: (PDFDocument) throws -> R
    ) rethrows -> R {
        try protectedPDFDocument.withLock { pdfDocument in
            try body(pdfDocument)
        }
    }

    @MainActor
    public func makePDFDocumentCopy() throws -> PDFDocument {
        guard let data = protectedPDFDocument.withLock({ $0.dataRepresentation() }),
              let pdfDocument = PDFDocument(data: data) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return pdfDocument
    }

    @MainActor
    public func replacePDFDocument(_ pdfDocument: sending PDFDocument) {
        objectWillChange.send()
        protectedPDFDocument.withLock { storedPDFDocument in
            storedPDFDocument = pdfDocument
        }
    }

    @MainActor
    public func replacePDFDocument(with data: Data) throws {
        guard let pdfDocument = PDFDocument(data: data) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        replacePDFDocument(pdfDocument)
    }

    // MARK: - ReferenceFileDocument Conformance
    public static let readableContentTypes: [UTType] = [.pdf]
    public static let writableContentTypes: [UTType] = [.pdf]

    public struct Snapshot: Sendable {
        public let data: Data
    }

    public init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
            let pdfDocument = PDFDocument(data: data)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }

        self.protectedPDFDocument = Mutex(pdfDocument)
    }

    public func snapshot(contentType: UTType) throws -> Snapshot {
        guard
            let data = protectedPDFDocument.withLock({ $0.dataRepresentation() }
            )
        else {
            throw CocoaError(.fileWriteUnknown)
        }

        return Snapshot(data: data)
    }

    public func fileWrapper(snapshot: Snapshot, configuration: WriteConfiguration)
        throws -> FileWrapper
    {
        FileWrapper(regularFileWithContents: snapshot.data)
    }
}

public typealias PDFEditorDocument = PDFAnnotatorDocument
