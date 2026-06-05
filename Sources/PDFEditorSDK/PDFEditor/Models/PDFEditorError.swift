import CoreGraphics
import Foundation

public enum PDFEditorError: Error, LocalizedError {
    case documentLoadFailed(URL)
    case documentNotLoaded
    case emptyDocument(URL?)
    case pageNotFound(index: Int)
    case invalidRenderSize(CGSize)
    case exportDocumentUnavailable
    case overlayMetadataUnavailable
    case documentWriteFailed(URL)
    case flattenedRenderFailed(URL)
    case generatedFileFinalizationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .documentLoadFailed(let url):
            return "Failed to load PDF at \(url.lastPathComponent)."
        case .documentNotLoaded:
            return "No PDF document is loaded."
        case .emptyDocument(let url):
            if let url {
                return "PDF at \(url.lastPathComponent) has no pages."
            }
            return "PDF document has no pages."
        case .pageNotFound(let index):
            return "PDF page \(index) was not found."
        case .invalidRenderSize(let size):
            return "Invalid render size \(Int(size.width)) x \(Int(size.height))."
        case .exportDocumentUnavailable:
            return "Could not create an editable export copy of the PDF."
        case .overlayMetadataUnavailable:
            return "Could not read the PDF overlay metadata."
        case .documentWriteFailed(let url):
            return "Failed to write PDF to \(url.lastPathComponent)."
        case .flattenedRenderFailed(let url):
            return "Failed to render flattened PDF to \(url.lastPathComponent)."
        case .generatedFileFinalizationFailed(let message):
            return "Failed to finalize generated PDF: \(message)"
        }
    }
}
