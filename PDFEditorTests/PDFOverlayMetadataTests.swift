import Foundation
import PDFKit
import Testing
import UIKit
@testable import PDFEditor

struct PDFOverlayMetadataTests {
    @Test
    @MainActor
    func readOverlayMetadataReturnsEmptyMetadataWhenAnnotationsAreAbsent() throws {
        let document = try PDFEditorTestSupport.makePDFDocument()

        let metadata = PDFOverlayRenderer.readOverlayMetadata(from: document)

        #expect(metadata.textBoxes.isEmpty)
        #expect(metadata.images.isEmpty)
        #expect(metadata.shapes.isEmpty)
    }

    @Test
    @MainActor
    func annotationWriterRoundTripsTextShapeAndImageMetadata() throws {
        let document = try PDFEditorTestSupport.makePDFDocument(pageCount: 2)
        let textID = UUID()
        let shapeID = UUID()
        let imageID = UUID()
        let imageBase64 = try PDFEditorTestSupport.makePNGBase64()
        let metadata = OverlayDocumentMetadata(
            textBoxes: [
                OverlayTextBoxMeta(
                    id: textID,
                    pageIndex: 0,
                    rect: RectCodable(CGRect(x: 12, y: 18, width: 100, height: 44)),
                    text: "Reviewed",
                    background: RGBAColor(.systemYellow),
                    fontSize: 18,
                    isBold: true,
                    textColor: RGBAColor(.systemRed),
                    textAlignment: NSTextAlignment.center.rawValue,
                    verticalAlignment: TextVerticalAlignment.middle.rawValue,
                    autoResize: true,
                    borderWidth: 2,
                    borderColor: RGBAColor(.systemBlue)
                )
            ],
            images: [
                OverlayImageMeta(
                    id: imageID,
                    pageIndex: 1,
                    rect: RectCodable(CGRect(x: 20, y: 24, width: 50, height: 60)),
                    imageBase64: imageBase64,
                    borderWidth: 1,
                    borderColor: RGBAColor(.black)
                )
            ],
            shapes: [
                OverlayShapeMeta(
                    id: shapeID,
                    pageIndex: 0,
                    rect: RectCodable(CGRect(x: 30, y: 40, width: 80, height: 70)),
                    kindRaw: OverlayShapeKind.arrow.rawValue,
                    strokeColor: RGBAColor(.systemGreen),
                    lineWidth: 4,
                    lineFlippedH: true,
                    lineFlippedV: false
                )
            ]
        )

        let addedAnnotations = PDFOverlayAnnotationWriter.write(metadata: metadata, to: document)
        let restored = PDFOverlayRenderer.readOverlayMetadata(from: document)

        #expect(addedAnnotations.count == 3)
        #expect(restored.textBoxes.count == 1)
        #expect(restored.textBoxes.first?.id == textID)
        #expect(restored.textBoxes.first?.text == "Reviewed")
        #expect(restored.textBoxes.first?.isBold == true)
        #expect(restored.textBoxes.first?.verticalAlignment == TextVerticalAlignment.middle.rawValue)
        #expect(restored.shapes.count == 1)
        #expect(restored.shapes.first?.id == shapeID)
        #expect(restored.shapes.first?.kindRaw == OverlayShapeKind.arrow.rawValue)
        #expect(restored.shapes.first?.lineFlippedH == true)
        #expect(restored.images.count == 1)
        #expect(restored.images.first?.id == imageID)
        #expect(restored.images.first?.imageBase64 == imageBase64)
    }

    @Test
    @MainActor
    func annotationWriterReplacesPreviouslyStoredOverlayAnnotations() throws {
        let document = try PDFEditorTestSupport.makePDFDocument()
        let first = OverlayDocumentMetadata(textBoxes: [
            OverlayTextBoxMeta(
                id: UUID(),
                pageIndex: 0,
                rect: RectCodable(CGRect(x: 10, y: 10, width: 50, height: 30)),
                text: "Old",
                background: RGBAColor(.systemYellow),
                fontSize: nil,
                isBold: nil,
                textColor: nil,
                textAlignment: nil,
                verticalAlignment: nil,
                autoResize: nil,
                borderWidth: nil,
                borderColor: nil
            )
        ])
        let secondID = UUID()
        let second = OverlayDocumentMetadata(shapes: [
            OverlayShapeMeta(
                id: secondID,
                pageIndex: 0,
                rect: RectCodable(CGRect(x: 15, y: 15, width: 90, height: 90)),
                kindRaw: OverlayShapeKind.rectangle.rawValue,
                strokeColor: RGBAColor(.systemPurple),
                lineWidth: 3,
                lineFlippedH: nil,
                lineFlippedV: nil
            )
        ])

        _ = PDFOverlayAnnotationWriter.write(metadata: first, to: document)
        _ = PDFOverlayAnnotationWriter.write(metadata: second, to: document)
        let restored = PDFOverlayRenderer.readOverlayMetadata(from: document)

        #expect(restored.textBoxes.isEmpty)
        #expect(restored.images.isEmpty)
        #expect(restored.shapes.count == 1)
        #expect(restored.shapes.first?.id == secondID)
    }

    @Test
    @MainActor
    func readOverlayMetadataDecodesLegacySingleAnnotationPayload() throws {
        let document = try PDFEditorTestSupport.makePDFDocument()
        let metadata = OverlayDocumentMetadata(textBoxes: [
            OverlayTextBoxMeta(
                id: UUID(),
                pageIndex: 0,
                rect: RectCodable(CGRect(x: 10, y: 10, width: 50, height: 30)),
                text: "Legacy",
                background: RGBAColor(.systemYellow),
                fontSize: nil,
                isBold: nil,
                textColor: nil,
                textAlignment: nil,
                verticalAlignment: nil,
                autoResize: nil,
                borderWidth: nil,
                borderColor: nil
            )
        ])
        let encoded = try JSONEncoder().encode(metadata).base64EncodedString()
        let annotation = PDFAnnotation(bounds: .zero, forType: .text, withProperties: nil)
        annotation.contents = PDFOverlayRenderer.overlayMetadataPrefix + encoded
        document.page(at: 0)?.addAnnotation(annotation)

        let restored = PDFOverlayRenderer.readOverlayMetadata(from: document)

        #expect(restored.textBoxes.count == 1)
        #expect(restored.textBoxes.first?.text == "Legacy")
    }

    @Test
    @MainActor
    func readOverlayMetadataDecodesLegacyMultipartPayload() throws {
        let document = try PDFEditorTestSupport.makePDFDocument()
        let metadata = OverlayDocumentMetadata(shapes: [
            OverlayShapeMeta(
                id: UUID(),
                pageIndex: 0,
                rect: RectCodable(CGRect(x: 10, y: 10, width: 50, height: 30)),
                kindRaw: OverlayShapeKind.circle.rawValue,
                strokeColor: RGBAColor(.systemRed),
                lineWidth: 2,
                lineFlippedH: nil,
                lineFlippedV: nil
            )
        ])
        let encoded = try JSONEncoder().encode(metadata).base64EncodedString()
        let splitIndex = encoded.index(encoded.startIndex, offsetBy: encoded.count / 2)
        let firstPart = String(encoded[..<splitIndex])
        let secondPart = String(encoded[splitIndex...])

        addLegacyPart(firstPart, part: 1, total: 2, to: document)
        addLegacyPart(secondPart, part: 2, total: 2, to: document)

        let restored = PDFOverlayRenderer.readOverlayMetadata(from: document)

        #expect(restored.shapes.count == 1)
        #expect(restored.shapes.first?.kindRaw == OverlayShapeKind.circle.rawValue)
    }

    @Test func lineEndpointCalculationPreservesStoredPDFCoordinateOrientation() {
        let rect = CGRect(x: 10, y: 20, width: 100, height: 80)

        let normal = PDFOverlayRenderer.overlayLineEndpoints(
            in: rect,
            kind: .line,
            lineWidth: 4,
            flippedH: false,
            flippedV: false
        )
        let flipped = PDFOverlayRenderer.overlayLineEndpoints(
            in: rect,
            kind: .line,
            lineWidth: 4,
            flippedH: true,
            flippedV: true
        )

        #expect(normal.start == CGPoint(x: 12, y: 98))
        #expect(normal.end == CGPoint(x: 108, y: 22))
        #expect(flipped.start == CGPoint(x: 108, y: 22))
        #expect(flipped.end == CGPoint(x: 12, y: 98))
    }

    private func addLegacyPart(
        _ partContents: String,
        part: Int,
        total: Int,
        to document: PDFDocument
    ) {
        let annotation = PDFAnnotation(bounds: .zero, forType: .text, withProperties: nil)
        annotation.contents = "\(PDFOverlayRenderer.overlayMetadataPartPrefix)\(part)/\(total):\(partContents)"
        document.page(at: 0)?.addAnnotation(annotation)
    }
}
