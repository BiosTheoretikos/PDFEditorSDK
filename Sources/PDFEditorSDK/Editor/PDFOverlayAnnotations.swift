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
