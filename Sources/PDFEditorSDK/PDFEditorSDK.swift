import SwiftUI
import PDFKit
import UIKit

/// Describes a PDF form field, used to determine whether it should receive a blue highlight overlay.
public struct PDFFormFieldInfo: Sendable {
    /// The internal field name (`/T` key in the PDF dictionary), if present.
    public let fieldName: String?
    /// True when the field's `/Ff` flags have the ReadOnly bit set (bit 0, value 1).
    public let isReadOnly: Bool
    /// True when the annotation's `/F` flags have the Locked bit set (bit 8, value 128).
    /// Some PDF authoring tools use this to prevent the field from being repositioned or edited by users.
    public let isAnnotationLocked: Bool
}

public enum PDFEditorDocumentKind: Sendable {
    case editable
    case flattened
}

public struct PDFEditorFileRequest: Sendable {
    public let kind: PDFEditorDocumentKind
    public let sourceURL: URL?
    public let temporaryURL: URL
    public let suggestedFileName: String

    public init(
        kind: PDFEditorDocumentKind,
        sourceURL: URL?,
        temporaryURL: URL,
        suggestedFileName: String
    ) {
        self.kind = kind
        self.sourceURL = sourceURL
        self.temporaryURL = temporaryURL
        self.suggestedFileName = suggestedFileName
    }
}

public typealias PDFEditorFileHandler = (PDFEditorFileRequest) throws -> URL

// MARK: - Static utilities

public enum PDFEditorSDK {

    /// Generates a thumbnail image for one page of an editable PDF saved by this SDK.
    ///
    /// Unlike a plain `page.draw()` call, this method also renders all overlay content
    /// (shapes, text boxes, images) that the SDK stores as embedded metadata rather than
    /// as visible PDF annotations.
    ///
    /// - Parameters:
    ///   - url: URL of an editable PDF produced by this SDK.
    ///   - pageIndex: Zero-based index of the page to render. Defaults to `0`.
    ///   - size: The pixel dimensions of the returned image.
    /// - Returns: A rendered `UIImage`.
    /// - Throws: `PDFEditorError` when the document, page, or render size is invalid.
    public static func thumbnail(for url: URL, pageIndex: Int = 0, size: CGSize) throws -> UIImage {
        guard size.width > 0, size.height > 0 else {
            throw PDFEditorError.invalidRenderSize(size)
        }
        guard let document = PDFDocument(url: url) else {
            throw PDFEditorError.documentLoadFailed(url)
        }
        guard let page = document.page(at: pageIndex) else {
            throw PDFEditorError.pageNotFound(index: pageIndex)
        }
        let metadata = PDFOverlayRenderer.readOverlayMetadata(from: document)
        let bounds = page.bounds(for: .mediaBox)
        let scale = min(size.width / bounds.width, size.height / bounds.height)
        let renderSize = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        let renderer = UIGraphicsImageRenderer(size: renderSize)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: renderSize))
            let cg = ctx.cgContext
            cg.scaleBy(x: scale, y: scale)
            PDFOverlayRenderer.renderPage(page, pageIndex: pageIndex, metadata: metadata,
                                          into: cg, bounds: bounds)
        }
    }

    /// Produces a flattened PDF from an editable PDF saved by this SDK.
    ///
    /// All overlay content (shapes, text boxes, images, ink drawings) and form field
    /// values are burned into the output as static PDF content. The result can be
    /// opened in any PDF viewer without needing the SDK.
    ///
    /// - Parameter url: URL of an editable PDF produced by this SDK.
    /// - Returns: A URL to a temporary file containing the flattened PDF.
    ///   Copy or move this file before the next call; it lives in `FileManager.temporaryDirectory`.
    /// - Throws: `PDFEditorError` or a file-system error if generation fails.
    public static func flattenedPDF(from url: URL) throws -> URL {
        guard let document = PDFDocument(url: url) else {
            throw PDFEditorError.documentLoadFailed(url)
        }
        guard document.pageCount > 0 else {
            throw PDFEditorError.emptyDocument(url)
        }
        let metadata = PDFOverlayRenderer.readOverlayMetadata(from: document)

        let baseName = url.deletingPathExtension().lastPathComponent
        let fileName = "\(baseName)-Flattened.pdf"
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent(fileName)
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )

        let firstBounds = document.page(at: 0)?.bounds(for: .mediaBox)
            ?? CGRect(x: 0, y: 0, width: 612, height: 792)
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = PDFOverlayRenderer.pdfDocumentInfo(from: document)
        let renderer = UIGraphicsPDFRenderer(bounds: firstBounds, format: format)

        try renderer.writePDF(to: outputURL) { context in
            for pageIndex in 0..<document.pageCount {
                guard let page = document.page(at: pageIndex) else { continue }
                let bounds = page.bounds(for: .mediaBox)
                context.beginPage(withBounds: bounds, pageInfo: [:])
                // applyFormFieldOverlay: false — the file was already written by PDFKit so
                // all appearance streams are committed. page.draw() renders them correctly,
                // and skipping the white-fill pass keeps ink strokes intact over form fields.
                PDFOverlayRenderer.renderPage(page, pageIndex: pageIndex, metadata: metadata,
                                              into: context.cgContext, bounds: bounds,
                                              applyFormFieldOverlay: false)
            }
        }
        return outputURL
    }
}

public struct PDFEditorView: View {
    @State private var viewModel: PDFFormViewModel
    private let showsDismissButton: Bool
    private let showsHighlightButton: Bool
    private let showsLockButton: Bool
    private let showsPencilButton: Bool
    private let showsSaveAlert: Bool

    /// - Parameters:
    ///   - url: The PDF document to open.
    ///   - showsDismissButton: Whether to show a leading Close button in the navigation bar.
    ///   - onSaveEditable: Called when the user saves the editable PDF.
    ///   - onExportFlattened: Called when the user exports a flattened PDF.
    ///   - showsHighlightButton: Whether to show the selected-text highlight button.
    ///   - showsLockButton: Whether to show the page scroll lock button.
    ///   - showsPencilButton: Whether to show the PencilKit button.
    ///   - showsSaveAlert: Whether to show the confirmation alert after saving. Defaults to `true`.
    ///     Set to `false` if your app already provides its own save confirmation UI.
    ///   - shouldHighlightFormField: Return `true` to show the blue highlight overlay for a field,
    ///     `false` to hide it. When `nil` (default), fields are highlighted unless they are
    ///     read-only (`isReadOnly`) or annotation-locked (`isAnnotationLocked`).
    public init(
        url: URL,
        showsDismissButton: Bool = false,
        onSaveEditable: PDFEditorFileHandler? = nil,
        onExportFlattened: PDFEditorFileHandler? = nil,
        showsHighlightButton: Bool = true,
        showsLockButton: Bool = true,
        showsPencilButton: Bool = true,
        showsSaveAlert: Bool = true,
        shouldHighlightFormField: ((PDFFormFieldInfo) -> Bool)? = nil
    ) {
        _viewModel = State(
            initialValue: PDFFormViewModel(
                documentURL: url,
                editableSaveHandler: onSaveEditable,
                flattenedExportHandler: onExportFlattened,
                shouldHighlightFormField: shouldHighlightFormField
            )
        )
        self.showsDismissButton = showsDismissButton
        self.showsHighlightButton = showsHighlightButton
        self.showsLockButton = showsLockButton
        self.showsPencilButton = showsPencilButton
        self.showsSaveAlert = showsSaveAlert
    }

    public var body: some View {
        PDFFormEditorView(
            viewModel: viewModel,
            showsDismissButton: showsDismissButton,
            showsHighlightButton: showsHighlightButton,
            showsLockButton: showsLockButton,
            showsPencilButton: showsPencilButton,
            showsSaveAlert: showsSaveAlert
        )
    }
}
