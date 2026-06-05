import UIKit
import PDFKit

// MARK: - Coordinate system
//
// PDFAnnotation.draw(with:in:) is called with a PDF y-UP context (origin at
// bottom-left of the page, y increases upward). This is true both for on-screen
// rendering and for appearance-stream generation during document.write(to:).
//
// Consequences for each drawing API:
//   UIBezierPath fill/stroke     — pure geometry, works correctly in y-up ✓
//   UIImage.draw(in:)            — applies an internal y-flip, compensates for
//                                  y-up automatically ✓
//   NSAttributedString.draw(in:) — applies an internal UIKit y-flip assuming a
//                                  y-DOWN UIKit context, which double-inverts
//                                  text in a y-up context ✗  → use CTFrameDraw
//   CTFrameDraw (CoreText)       — designed for y-up, renders correctly ✓
//
// For path geometry: in y-up space, maxY is the VISUAL TOP of a rect and
// minY is the VISUAL BOTTOM (the opposite of UIKit y-down convention).

// MARK: - Text Box

/// FreeText annotation with an explicitly drawn background so the appearance
/// stream faithfully mirrors the editor view in any PDF viewer.
///
/// Background and border use `UIBezierPath` (y-up safe geometry).
/// Text uses `PDFOverlayRenderer.drawText` (CoreText — y-up native).
/// `NSAttributedString.draw` is intentionally avoided; its internal UIKit
/// y-flip double-inverts text in the y-up annotation context.
final class PDFTextBoxAnnotation: PDFAnnotation {

    struct Style {
        let text:               String
        let fontSize:           CGFloat
        let isBold:             Bool
        let textColor:          UIColor
        let backgroundColor:    UIColor
        let textAlignment:      NSTextAlignment
        let verticalAlignment:  TextVerticalAlignment
        let borderWidth:        CGFloat
        let borderColor:        UIColor
    }

    var style: Style?

    init(bounds: CGRect) {
        super.init(bounds: bounds, forType: .freeText, withProperties: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    override func draw(with box: PDFDisplayBox, in context: CGContext) {
        guard let s = style else { return }

        let rect          = bounds
        let cornerRadius: CGFloat = 6
        let padding       = UIEdgeInsets(top: 6, left: 8, bottom: 6, right: 8)

        // ── Background & border ──────────────────────────────────────────────
        // Push the annotation context so UIBezierPath's fill/stroke methods
        // draw into it. UIBezierPath does not apply any y-axis assumptions so
        // it works correctly in the y-up annotation context.
        UIGraphicsPushContext(context)

        let bgPath = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
        s.backgroundColor.setFill()
        bgPath.fill()

        if s.borderWidth > 0 {
            let borderPath = UIBezierPath(
                roundedRect: rect.insetBy(dx: s.borderWidth / 2, dy: s.borderWidth / 2),
                cornerRadius: cornerRadius)
            borderPath.lineWidth = s.borderWidth
            s.borderColor.setStroke()
            borderPath.stroke()
        }

        UIGraphicsPopContext()

        // ── Text ─────────────────────────────────────────────────────────────
        // Use PDFOverlayRenderer.drawText which calls CTFrameDraw directly.
        // CoreText is designed for y-up contexts and renders text correctly
        // without any additional coordinate transforms.
        PDFOverlayRenderer.drawText(
            s.text, in: rect.inset(by: padding),
            fontSize:          s.fontSize,
            isBold:            s.isBold,
            textColor:         s.textColor,
            textAlignment:     s.textAlignment,
            verticalAlignment: s.verticalAlignment,
            context:           context)
    }
}

// MARK: - Triangle

/// Stamp annotation whose appearance stream draws an upward-pointing triangle (▲).
final class PDFTriangleAnnotation: PDFAnnotation {
    var shapeColor:     UIColor  = .black
    var shapeLineWidth: CGFloat  = 2.0

    init(bounds: CGRect) {
        super.init(bounds: bounds, forType: .stamp, withProperties: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    override func draw(with box: PDFDisplayBox, in context: CGContext) {
        let rect  = bounds
        let inset = shapeLineWidth / 2
        let r     = rect.insetBy(dx: inset, dy: inset)

        context.saveGState()
        context.setStrokeColor(shapeColor.cgColor)
        context.setLineWidth(shapeLineWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        // y-UP context: maxY is the VISUAL TOP of the rect.
        // Apex at maxY → triangle points UP ▲.
        context.move(to:    CGPoint(x: r.midX, y: r.maxY))   // apex
        context.addLine(to: CGPoint(x: r.maxX, y: r.minY))   // bottom-right
        context.addLine(to: CGPoint(x: r.minX, y: r.minY))   // bottom-left
        context.closePath()
        context.strokePath()
        context.restoreGState()
    }
}

// MARK: - Image

/// Stamp annotation whose appearance stream contains the overlay image.
final class PDFImageAnnotation: PDFAnnotation {
    var overlayImage:     UIImage?
    var imageBorderWidth: CGFloat  = 0
    var imageBorderColor: UIColor  = .black

    init(bounds: CGRect) {
        super.init(bounds: bounds, forType: .stamp, withProperties: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    override func draw(with box: PDFDisplayBox, in context: CGContext) {
        guard let image = overlayImage else { return }

        let rect          = bounds
        let cornerRadius: CGFloat = 6

        context.saveGState()
        context.addPath(UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius).cgPath)
        context.clip()
        PDFOverlayRenderer.drawOverlayImage(image, in: rect, context: context)
        context.restoreGState()

        if imageBorderWidth > 0 {
            context.saveGState()
            context.setStrokeColor(imageBorderColor.cgColor)
            context.setLineWidth(imageBorderWidth)
            context.addPath(UIBezierPath(
                roundedRect: rect.insetBy(dx: imageBorderWidth / 2, dy: imageBorderWidth / 2),
                cornerRadius: cornerRadius
            ).cgPath)
            context.strokePath()
            context.restoreGState()
        }
    }
}

// MARK: - Overlay Annotation Writer

enum PDFOverlayAnnotationWriter {
    static func write(
        metadata: OverlayDocumentMetadata,
        to document: PDFDocument
    ) -> [(PDFPage, PDFAnnotation)] {
        removeExistingOverlayAnnotations(from: document)

        var added: [(PDFPage, PDFAnnotation)] = []

        for meta in metadata.textBoxes {
            guard let page = document.page(at: meta.pageIndex),
                  let annotation = makeTextBoxAnnotation(meta: meta) else { continue }
            page.addAnnotation(annotation)
            added.append((page, annotation))
        }

        for meta in metadata.shapes {
            guard let page = document.page(at: meta.pageIndex),
                  let annotation = makeShapeAnnotation(meta: meta) else { continue }
            page.addAnnotation(annotation)
            added.append((page, annotation))
        }

        for meta in metadata.images {
            guard let page = document.page(at: meta.pageIndex),
                  let annotation = makeImageAnnotation(meta: meta) else { continue }
            page.addAnnotation(annotation)
            added.append((page, annotation))
        }

        return added
    }

    private static func removeExistingOverlayAnnotations(from document: PDFDocument) {
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            for annotation in page.annotations where isStoredOverlayAnnotation(annotation) {
                page.removeAnnotation(annotation)
            }
        }
    }

    private static func isStoredOverlayAnnotation(_ annotation: PDFAnnotation) -> Bool {
        annotation.value(forAnnotationKey: PDFOverlayRenderer.overlayAnnotationKey) != nil
        || annotation.contents?.hasPrefix(PDFOverlayRenderer.overlayMetadataPrefix) == true
        || annotation.contents?.hasPrefix(PDFOverlayRenderer.overlayMetadataPartPrefix) == true
    }

    private static func makeTextBoxAnnotation(meta: OverlayTextBoxMeta) -> PDFAnnotation? {
        let rect = meta.rect.cgRect
        let annotation = PDFTextBoxAnnotation(bounds: rect)

        annotation.style = PDFTextBoxAnnotation.Style(
            text: meta.text,
            fontSize: meta.fontSize ?? 14,
            isBold: meta.isBold ?? false,
            textColor: meta.textColor?.uiColor ?? .black,
            backgroundColor: meta.background.uiColor,
            textAlignment: NSTextAlignment(rawValue: meta.textAlignment ?? 0) ?? .left,
            verticalAlignment: TextVerticalAlignment(rawValue: meta.verticalAlignment ?? "") ?? .top,
            borderWidth: meta.borderWidth ?? 0,
            borderColor: meta.borderColor?.uiColor ?? .black
        )

        annotation.contents = meta.text
        annotation.font = meta.isBold == true
            ? UIFont.boldSystemFont(ofSize: meta.fontSize ?? 14)
            : UIFont.systemFont(ofSize: meta.fontSize ?? 14)
        annotation.fontColor = meta.textColor?.uiColor ?? .black
        annotation.alignment = NSTextAlignment(rawValue: meta.textAlignment ?? 0) ?? .left

        annotation.shouldDisplay = true
        annotation.shouldPrint = true
        storeOverlayPayload(meta, kind: "text", on: annotation)
        return annotation
    }

    private static func makeShapeAnnotation(meta: OverlayShapeMeta) -> PDFAnnotation? {
        guard let kind = OverlayShapeKind(rawValue: meta.kindRaw) else { return nil }
        let rect = meta.rect.cgRect
        let strokeColor = meta.strokeColor.uiColor
        let lineWidth = meta.lineWidth
        let border = PDFBorder()
        border.lineWidth = lineWidth

        let annotation: PDFAnnotation

        switch kind {
        case .circle:
            annotation = PDFAnnotation(bounds: rect, forType: .circle, withProperties: nil)
            annotation.color = strokeColor
            annotation.border = border
            if #available(iOS 16.0, *) { annotation.interiorColor = .clear }

        case .rectangle:
            annotation = PDFAnnotation(bounds: rect, forType: .square, withProperties: nil)
            annotation.color = strokeColor
            annotation.border = border
            if #available(iOS 16.0, *) { annotation.interiorColor = .clear }

        case .triangle:
            let tri = PDFTriangleAnnotation(bounds: rect)
            tri.shapeColor = strokeColor
            tri.shapeLineWidth = lineWidth
            annotation = tri

        case .line, .arrow, .doubleArrow:
            let endpoints = PDFOverlayRenderer.overlayLineEndpoints(
                in: rect,
                kind: kind,
                lineWidth: lineWidth,
                flippedH: meta.lineFlippedH ?? false,
                flippedV: meta.lineFlippedV ?? false
            )

            annotation = PDFAnnotation(bounds: rect, forType: .line, withProperties: nil)
            annotation.color = strokeColor
            annotation.border = border
            annotation.setValue(
                [endpoints.start.x, endpoints.start.y, endpoints.end.x, endpoints.end.y] as [NSNumber],
                forAnnotationKey: PDFAnnotationKey(rawValue: "/L")
            )

            if kind == .arrow {
                annotation.setValue(
                    ["None", "OpenArrow"] as [NSString],
                    forAnnotationKey: PDFAnnotationKey(rawValue: "/LE")
                )
            } else if kind == .doubleArrow {
                annotation.setValue(
                    ["OpenArrow", "OpenArrow"] as [NSString],
                    forAnnotationKey: PDFAnnotationKey(rawValue: "/LE")
                )
            }
        }

        annotation.shouldDisplay = true
        annotation.shouldPrint = true
        storeOverlayPayload(meta, kind: "shape", on: annotation)
        return annotation
    }

    private static func makeImageAnnotation(meta: OverlayImageMeta) -> PDFAnnotation? {
        guard let data = Data(base64Encoded: meta.imageBase64),
              let image = UIImage(data: data) else { return nil }

        let annotation = PDFImageAnnotation(bounds: meta.rect.cgRect)
        annotation.overlayImage = image
        annotation.imageBorderWidth = meta.borderWidth ?? 0
        annotation.imageBorderColor = meta.borderColor?.uiColor ?? .black
        annotation.shouldDisplay = true
        annotation.shouldPrint = true
        storeOverlayPayload(meta, kind: "image", on: annotation)
        return annotation
    }

    private static func storeOverlayPayload<T: Encodable>(_ value: T, kind: String, on annotation: PDFAnnotation) {
        do {
            let json = try JSONEncoder().encode(value)
            guard let base64 = String(data: json.base64EncodedData(), encoding: .utf8) else { return }
            annotation.setValue(
                "\(kind):\(base64)" as NSString,
                forAnnotationKey: PDFOverlayRenderer.overlayAnnotationKey
            )
        } catch {
            assertionFailure("Failed to encode overlay payload: \(error.localizedDescription)")
        }
    }
}
