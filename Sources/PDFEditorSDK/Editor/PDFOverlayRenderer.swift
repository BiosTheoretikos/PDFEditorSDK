import UIKit
import PDFKit

/// Internal rendering helpers shared between `PDFFormViewModel` (live flattened export)
/// and the public static API (`PDFEditorSDK.thumbnail`, `PDFEditorSDK.flattenedPDF`).
enum PDFOverlayRenderer {

    // MARK: - Metadata constants

    static let overlayMetadataPrefix     = "OVERLAY_META_V1:"
    static let overlayMetadataPartPrefix = "OVERLAY_META_V1_PART:"

    // MARK: - Overlay metadata I/O

    /// Reads the overlay metadata blob embedded in an editable PDF document.
    /// Returns an empty `OverlayDocumentMetadata` when no metadata annotations are found.
    static func readOverlayMetadata(from document: PDFDocument) -> OverlayDocumentMetadata {
        var encoded: String?
        var parts: [Int: String] = [:]
        var totalParts: Int?

        outer: for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            for annotation in page.annotations {
                guard let contents = annotation.contents else { continue }
                if contents.hasPrefix(overlayMetadataPrefix) {
                    encoded = String(contents.dropFirst(overlayMetadataPrefix.count))
                    break outer
                }
                if contents.hasPrefix(overlayMetadataPartPrefix) {
                    let tail = String(contents.dropFirst(overlayMetadataPartPrefix.count))
                    let components = tail.split(separator: ":", maxSplits: 1)
                    guard components.count == 2 else { continue }
                    let header = components[0].split(separator: "/")
                    guard header.count == 2,
                          let part = Int(header[0]),
                          let total = Int(header[1]) else { continue }
                    totalParts = total
                    parts[part] = String(components[1])
                }
            }
        }

        if encoded == nil, let totalParts, parts.count == totalParts {
            encoded = (1...totalParts).compactMap { parts[$0] }.joined()
        }

        guard let encoded,
              let data = Data(base64Encoded: encoded),
              let metadata = try? JSONDecoder().decode(OverlayDocumentMetadata.self, from: data)
        else {
            return OverlayDocumentMetadata()
        }
        return metadata
    }

    // MARK: - Page rendering

    /// Renders `page` with all overlay items for that page drawn on top.
    ///
    /// The caller is responsible for setting up the coordinate transform so that
    /// PDF space (origin at bottom-left) maps correctly onto `cg`.
    static func renderPage(
        _ page: PDFPage,
        pageIndex: Int,
        metadata: OverlayDocumentMetadata,
        into cg: CGContext,
        bounds: CGRect
    ) {
        cg.saveGState()
        cg.translateBy(x: 0, y: bounds.height)
        cg.scaleBy(x: 1, y: -1)

        page.draw(with: .mediaBox, to: cg)
        cg.textMatrix = .identity

        renderFormFieldOverlay(for: page, in: cg)

        let textItems = metadata.textBoxes.filter { $0.pageIndex == pageIndex }
        for item in textItems {
            let rect = item.rect.cgRect
            let cornerRadius: CGFloat = 6
            let padding = UIEdgeInsets(top: 6, left: 8, bottom: 6, right: 8)

            cg.saveGState()
            cg.addPath(UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius).cgPath)
            cg.setFillColor(item.background.uiColor.cgColor)
            cg.fillPath()
            cg.restoreGState()

            drawText(
                item.text,
                in: rect.inset(by: padding),
                fontSize: item.fontSize ?? 14,
                isBold: item.isBold ?? false,
                textColor: item.textColor?.uiColor ?? .label,
                textAlignment: NSTextAlignment(rawValue: item.textAlignment ?? 0) ?? .left,
                verticalAlignment: TextVerticalAlignment(rawValue: item.verticalAlignment ?? "") ?? .top,
                context: cg
            )

            if let bw = item.borderWidth, bw > 0 {
                let bc = item.borderColor?.uiColor ?? .black
                cg.saveGState()
                cg.setStrokeColor(bc.cgColor)
                cg.setLineWidth(bw)
                cg.addPath(UIBezierPath(
                    roundedRect: rect.insetBy(dx: bw / 2, dy: bw / 2),
                    cornerRadius: cornerRadius
                ).cgPath)
                cg.strokePath()
                cg.restoreGState()
            }
        }

        let imageItems = metadata.images.filter { $0.pageIndex == pageIndex }
        for item in imageItems {
            guard let data = Data(base64Encoded: item.imageBase64),
                  let cgImage = UIImage(data: data)?.cgImage else { continue }
            let rect = item.rect.cgRect
            let cornerRadius: CGFloat = 6
            cg.saveGState()
            cg.addPath(UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius).cgPath)
            cg.clip()
            cg.draw(cgImage, in: aspectFitRect(for: cgImage, in: rect))
            cg.restoreGState()

            if let bw = item.borderWidth, bw > 0 {
                let bc = item.borderColor?.uiColor ?? .black
                cg.saveGState()
                cg.setStrokeColor(bc.cgColor)
                cg.setLineWidth(bw)
                cg.addPath(UIBezierPath(
                    roundedRect: rect.insetBy(dx: bw / 2, dy: bw / 2),
                    cornerRadius: cornerRadius
                ).cgPath)
                cg.strokePath()
                cg.restoreGState()
            }
        }

        let shapeItems = metadata.shapes.filter { $0.pageIndex == pageIndex }
        for item in shapeItems {
            guard let kind = OverlayShapeKind(rawValue: item.kindRaw) else { continue }
            let rect = item.rect.cgRect
            let insetRect = rect.insetBy(dx: item.lineWidth / 2, dy: item.lineWidth / 2)
            cg.saveGState()
            cg.setStrokeColor(item.strokeColor.uiColor.cgColor)
            cg.setLineWidth(item.lineWidth)
            cg.setLineCap(.round)
            cg.setLineJoin(.round)
            switch kind {
            case .circle:
                cg.addEllipse(in: insetRect)
            case .rectangle:
                cg.addPath(UIBezierPath(roundedRect: insetRect, cornerRadius: 4).cgPath)
            case .triangle:
                cg.move(to: CGPoint(x: insetRect.midX, y: insetRect.minY))
                cg.addLine(to: CGPoint(x: insetRect.maxX, y: insetRect.maxY))
                cg.addLine(to: CGPoint(x: insetRect.minX, y: insetRect.maxY))
                cg.closePath()
            case .line:
                let pts = overlayLineEndpoints(in: rect, kind: kind, lineWidth: item.lineWidth,
                                               flippedH: item.lineFlippedH ?? false, flippedV: item.lineFlippedV ?? false)
                cg.move(to: pts.start)
                cg.addLine(to: pts.end)
            case .arrow:
                let pts = overlayLineEndpoints(in: rect, kind: kind, lineWidth: item.lineWidth,
                                               flippedH: item.lineFlippedH ?? false, flippedV: item.lineFlippedV ?? false)
                cg.move(to: pts.start)
                cg.addLine(to: pts.end)
                addArrowhead(from: pts.start, to: pts.end, lineWidth: item.lineWidth, context: cg)
            case .doubleArrow:
                let pts = overlayLineEndpoints(in: rect, kind: kind, lineWidth: item.lineWidth,
                                               flippedH: item.lineFlippedH ?? false, flippedV: item.lineFlippedV ?? false)
                cg.move(to: pts.start)
                cg.addLine(to: pts.end)
                addArrowhead(from: pts.start, to: pts.end, lineWidth: item.lineWidth, context: cg)
                addArrowhead(from: pts.end, to: pts.start, lineWidth: item.lineWidth, context: cg)
            }
            cg.strokePath()
            cg.restoreGState()
        }

        cg.restoreGState()
    }

    // MARK: - Form field overlay

    static func renderFormFieldOverlay(for page: PDFPage, in context: CGContext) {
        for annotation in page.annotations {
            let fieldType = annotation.widgetFieldType

            if fieldType == .button {
                let ct = annotation.widgetControlType
                guard ct == .checkBoxControl || ct == .radioButtonControl else { continue }
                let value = annotation.widgetStringValue ?? "Off"
                guard value != "Off", !value.isEmpty else { continue }
                let appearanceState = annotation.value(forAnnotationKey: PDFAnnotationKey(rawValue: "/AS")) as? String ?? "Off"
                guard appearanceState != value else { continue }
                let bounds = annotation.bounds
                guard bounds.width > 1, bounds.height > 1 else { continue }
                let symbol = ct == .radioButtonControl ? "•" : "✓"
                let fontSize = min(bounds.width, bounds.height) * 0.75
                drawText(symbol, in: bounds, fontSize: fontSize, isBold: false, textColor: .black,
                         textAlignment: .center, verticalAlignment: .middle, context: context)
                continue
            }

            guard fieldType == .text || fieldType == .choice else { continue }
            guard let text = annotation.widgetStringValue, !text.isEmpty else { continue }
            let bounds = annotation.bounds
            guard bounds.width > 1, bounds.height > 1 else { continue }

            context.saveGState()
            context.setFillColor(UIColor.white.cgColor)
            context.fill(bounds.insetBy(dx: 1, dy: 1))
            context.restoreGState()

            let font   = annotation.font ?? UIFont.systemFont(ofSize: 12)
            let isBold = font.fontDescriptor.symbolicTraits.contains(.traitBold)
            let color  = annotation.fontColor ?? UIColor.black
            let align  = annotation.alignment
            let padding = UIEdgeInsets(top: 2, left: 4, bottom: 2, right: 4)
            drawText(text, in: bounds.inset(by: padding), fontSize: font.pointSize, isBold: isBold,
                     textColor: color, textAlignment: align, verticalAlignment: .middle, context: context)
        }
    }

    // MARK: - Drawing primitives

    static func drawText(
        _ text: String,
        in rect: CGRect,
        fontSize: CGFloat,
        isBold: Bool,
        textColor: UIColor,
        textAlignment: NSTextAlignment = .left,
        verticalAlignment: TextVerticalAlignment = .top,
        context: CGContext
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = textAlignment
        paragraph.lineBreakMode = .byWordWrapping
        let font = isBold ? UIFont.boldSystemFont(ofSize: fontSize) : UIFont.systemFont(ofSize: fontSize)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraph
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let framesetter = CTFramesetterCreateWithAttributedString(attributed)

        var drawRect = rect
        if verticalAlignment != .top {
            let constraints = CGSize(width: rect.width, height: .greatestFiniteMagnitude)
            let suggested = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRangeMake(0, 0), nil, constraints, nil)
            let textHeight = min(suggested.height, rect.height)
            switch verticalAlignment {
            case .top: break
            case .middle:
                let offset = max(0, (rect.height - textHeight) / 2)
                drawRect = CGRect(x: rect.minX, y: rect.minY + offset, width: rect.width, height: rect.height - offset)
            case .bottom:
                let offset = max(0, rect.height - textHeight)
                drawRect = CGRect(x: rect.minX, y: rect.minY + offset, width: rect.width, height: rect.height - offset)
            }
        }

        context.saveGState()
        context.textMatrix = .identity
        let path = CGPath(rect: drawRect, transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, attributed.length), path, nil)
        CTFrameDraw(frame, context)
        context.textMatrix = .identity
        context.restoreGState()
    }

    static func aspectFitRect(for image: CGImage, in rect: CGRect) -> CGRect {
        let imageSize = CGSize(width: image.width, height: image.height)
        guard imageSize.width > 0, imageSize.height > 0 else { return rect }
        let scale = min(rect.width / imageSize.width, rect.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            origin: CGPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2),
            size: size
        )
    }

    static func overlayLineEndpoints(
        in rect: CGRect,
        kind: OverlayShapeKind,
        lineWidth: CGFloat,
        flippedH: Bool,
        flippedV: Bool
    ) -> (start: CGPoint, end: CGPoint) {
        let inset = ShapeBoxView.lineDrawingInset(for: kind, lineWidth: lineWidth)
        let drawableRect = rect.insetBy(dx: min(inset, rect.width / 2), dy: min(inset, rect.height / 2))
        return (
            start: CGPoint(
                x: flippedH ? drawableRect.maxX : drawableRect.minX,
                y: flippedV ? drawableRect.maxY : drawableRect.minY
            ),
            end: CGPoint(
                x: flippedH ? drawableRect.minX : drawableRect.maxX,
                y: flippedV ? drawableRect.minY : drawableRect.maxY
            )
        )
    }

    static func addArrowhead(from start: CGPoint, to end: CGPoint, lineWidth: CGFloat, context: CGContext) {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = hypot(dx, dy)
        guard length > 1 else { return }
        let angle = atan2(dy, dx)
        let headLength = max(lineWidth * 5, 18)
        let headAngle: CGFloat = .pi / 6
        context.move(to: CGPoint(x: end.x - headLength * cos(angle - headAngle),
                                  y: end.y - headLength * sin(angle - headAngle)))
        context.addLine(to: end)
        context.addLine(to: CGPoint(x: end.x - headLength * cos(angle + headAngle),
                                     y: end.y - headLength * sin(angle + headAngle)))
    }

    // MARK: - Document info

    static func pdfDocumentInfo(from document: PDFDocument) -> [String: Any] {
        guard let attributes = document.documentAttributes else { return [:] }
        var info: [String: Any] = [:]
        if let title = attributes[PDFDocumentAttribute.titleAttribute] as? String, !title.isEmpty {
            info[kCGPDFContextTitle as String] = title
        }
        if let author = attributes[PDFDocumentAttribute.authorAttribute] as? String, !author.isEmpty {
            info[kCGPDFContextAuthor as String] = author
        }
        if let subject = attributes[PDFDocumentAttribute.subjectAttribute] as? String, !subject.isEmpty {
            info[kCGPDFContextSubject as String] = subject
        }
        if let creator = attributes[PDFDocumentAttribute.creatorAttribute] as? String, !creator.isEmpty {
            info[kCGPDFContextCreator as String] = creator
        }
        if let keywords = attributes[PDFDocumentAttribute.keywordsAttribute] {
            if let keywordString = keywords as? String, !keywordString.isEmpty {
                info[kCGPDFContextKeywords as String] = keywordString
            } else if let keywordList = keywords as? [String], !keywordList.isEmpty {
                info[kCGPDFContextKeywords as String] = keywordList
            }
        }
        return info
    }
}
