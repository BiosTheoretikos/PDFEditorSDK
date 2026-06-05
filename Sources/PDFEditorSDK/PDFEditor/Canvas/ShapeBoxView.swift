//
//  ShapeBoxView.swift
//  PDFEditorSDK
//

import SwiftUI
import PDFKit
import UIKit

final class ShapeBoxView: UIView {
    let id: UUID
    private(set) var shapeKind: OverlayShapeKind
    private(set) var strokeColor: UIColor
    private(set) var lineWidth: CGFloat
    /// For .line/.arrow: true when the start endpoint is on the right side of the frame.
    private(set) var lineFlippedH: Bool = false
    /// For .line/.arrow: true when the start endpoint is below the end endpoint.
    private(set) var lineFlippedV: Bool = false

    var onSelect: ((UUID) -> Void)?
    var onEndChange: ((OverlayShapeState, OverlayShapeState) -> Void)?

    private var isSelectMode: Bool = false
    private var isSelected: Bool = false

    private let selectionBorderLayer = CAShapeLayer()
    // Primary handle: moves whole shape (non-line) or start endpoint (line/arrow)
    private let moveHandle = UIView()
    private let moveIcon = UIImageView()
    // Secondary handle: resizes (non-line) or moves end endpoint (line/arrow)
    private let resizeHitTarget = ResizeHandleHitTargetView()
    private let resizeHandleVisual = UIView()
    private let resizeIcon = UIImageView()
    private var pinchGesture: UIPinchGestureRecognizer?
    private let resizeFeedback = UIImpactFeedbackGenerator(style: .light)
    private let minSize = CGSize(width: 30, height: 30)
    private let minLineSize = CGSize(width: 5, height: 5)
    private let resizeVisualSize: CGFloat = 24
    private var pinchStartFrame: CGRect = .zero
    private var startFrame: CGRect = .zero
    private var startLineFlippedH: Bool = false
    private var startLineFlippedV: Bool = false

    private var isLineKind: Bool { shapeKind == .line || shapeKind == .arrow || shapeKind == .doubleArrow }
    private var lineDrawingInset: CGFloat {
        Self.lineDrawingInset(for: shapeKind, lineWidth: lineWidth)
    }
    private var lineDrawableBounds: CGRect {
        let inset = min(lineDrawingInset, bounds.width / 2, bounds.height / 2)
        return bounds.insetBy(dx: inset, dy: inset)
    }

    // Endpoints in bounds coordinates
    private var lineStartInBounds: CGPoint {
        let drawableBounds = lineDrawableBounds
        return CGPoint(
            x: lineFlippedH ? drawableBounds.maxX : drawableBounds.minX,
            y: lineFlippedV ? drawableBounds.maxY : drawableBounds.minY
        )
    }
    private var lineEndInBounds: CGPoint {
        let drawableBounds = lineDrawableBounds
        return CGPoint(
            x: lineFlippedH ? drawableBounds.minX : drawableBounds.maxX,
            y: lineFlippedV ? drawableBounds.minY : drawableBounds.maxY
        )
    }

    init(id: UUID, kind: OverlayShapeKind, strokeColor: UIColor, lineWidth: CGFloat) {
        self.id = id
        self.shapeKind = kind
        self.strokeColor = strokeColor
        self.lineWidth = lineWidth
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        self.id = UUID()
        self.shapeKind = .rectangle
        self.strokeColor = .systemRed
        self.lineWidth = 2.0
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        isOpaque = false
        backgroundColor = .clear
        clipsToBounds = false

        // Selection border layer (blue dashed outline)
        selectionBorderLayer.fillColor = UIColor.clear.cgColor
        selectionBorderLayer.strokeColor = UIColor.systemBlue.cgColor
        selectionBorderLayer.lineWidth = 2
        selectionBorderLayer.lineDashPattern = [6, 4]
        selectionBorderLayer.isHidden = true
        layer.addSublayer(selectionBorderLayer)

        // Move/start handle (blue)
        moveHandle.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.12)
        moveHandle.layer.cornerRadius = 6
        moveHandle.layer.borderWidth = 1
        moveHandle.layer.borderColor = UIColor.systemBlue.cgColor
        moveIcon.image = UIImage(systemName: "arrow.up.and.down.and.arrow.left.and.right")
        moveIcon.tintColor = UIColor.systemBlue
        moveIcon.contentMode = .scaleAspectFit
        moveHandle.addSubview(moveIcon)
        addSubview(moveHandle)

        // Resize/end handle (orange)
        resizeHandleVisual.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.12)
        resizeHandleVisual.layer.cornerRadius = 6
        resizeHandleVisual.layer.borderWidth = 1
        resizeHandleVisual.layer.borderColor = UIColor.systemOrange.cgColor
        resizeIcon.image = UIImage(systemName: "arrow.up.left.and.down.right")
        resizeIcon.tintColor = UIColor.systemOrange
        resizeIcon.contentMode = .scaleAspectFit
        resizeHandleVisual.addSubview(resizeIcon)
        resizeHitTarget.addSubview(resizeHandleVisual)
        addSubview(resizeHitTarget)
        resizeHitTarget.isUserInteractionEnabled = true

        let movePan = UIPanGestureRecognizer(target: self, action: #selector(handleMovePan(_:)))
        moveHandle.addGestureRecognizer(movePan)
        moveHandle.isUserInteractionEnabled = true

        let bodyPan = UIPanGestureRecognizer(target: self, action: #selector(handleBodyMovePan(_:)))
        addGestureRecognizer(bodyPan)

        let resizePan = UIPanGestureRecognizer(target: self, action: #selector(handleResizePan(_:)))
        resizeHitTarget.addGestureRecognizer(resizePan)

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinchGesture = pinch
        addGestureRecognizer(pinch)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleSelect))
        addGestureRecognizer(tap)

        updateHandleVisibility()
    }

    /// Sets the line orientation flags and triggers redraw/layout.
    func applyLineOrientation(flippedH: Bool, flippedV: Bool) {
        lineFlippedH = flippedH
        lineFlippedV = flippedV
        setNeedsDisplay()
        setNeedsLayout()
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if isLineKind {
            return lineHitTest(point, with: event)
        }
        return overlayHitTestForwardingOutOfBounds(host: self, point: point, event: event) { p, e in
            super.hitTest(p, with: e)
        }
    }

    private func lineHitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard isUserInteractionEnabled, !isHidden, alpha > 0.01 else { return nil }

        for subview in subviews.reversed() {
            guard subview.isUserInteractionEnabled, !subview.isHidden, subview.alpha > 0.01 else { continue }
            let convertedPoint = subview.convert(point, from: self)
            if let hit = subview.hitTest(convertedPoint, with: event) {
                return hit
            }
        }

        guard bounds.contains(point), lineInteractionPath().contains(point) else { return nil }
        return self
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let handleSize: CGFloat = 16
        let v = resizeVisualSize

        if isLineKind {
            // Position handles at the line endpoints
            let startCorner = lineStartCornerOffset(handleSize: handleSize)
            let endCorner   = lineEndCornerOffset(handleSize: v)
            moveHandle.frame = CGRect(origin: startCorner, size: CGSize(width: handleSize, height: handleSize))
            resizeHitTarget.frame = CGRect(origin: endCorner, size: CGSize(width: v, height: v))
        } else {
            moveHandle.frame = CGRect(x: -6, y: -6, width: handleSize, height: handleSize)
            resizeHitTarget.frame = CGRect(
                x: bounds.width - v + 6,
                y: bounds.height - v + 6,
                width: v, height: v
            )
        }
        moveIcon.frame = moveHandle.bounds.insetBy(dx: 2, dy: 2)
        resizeHandleVisual.frame = resizeHitTarget.bounds
        resizeIcon.frame = resizeHandleVisual.bounds.insetBy(dx: 3, dy: 3)

        // Selection border
        selectionBorderLayer.frame = bounds
        selectionBorderLayer.path = selectionPath().cgPath
    }

    // Returns the frame origin for the start-point handle (centered on the start corner).
    private func lineStartCornerOffset(handleSize: CGFloat) -> CGPoint {
        let start = lineStartInBounds
        return CGPoint(x: start.x - handleSize / 2, y: start.y - handleSize / 2)
    }

    // Returns the frame origin for the end-point handle (centered on the end corner).
    private func lineEndCornerOffset(handleSize: CGFloat) -> CGPoint {
        let end = lineEndInBounds
        return CGPoint(x: end.x - handleSize / 2, y: end.y - handleSize / 2)
    }

    private func selectionPath() -> UIBezierPath {
        let inset = max(lineWidth / 2, 1)
        let r = bounds.insetBy(dx: inset, dy: inset)
        switch shapeKind {
        case .circle:
            return UIBezierPath(ovalIn: r)
        case .rectangle:
            return UIBezierPath(roundedRect: r, cornerRadius: 4)
        case .triangle:
            let path = UIBezierPath()
            path.move(to:    CGPoint(x: r.midX,  y: r.minY))
            path.addLine(to: CGPoint(x: r.maxX,  y: r.maxY))
            path.addLine(to: CGPoint(x: r.minX,  y: r.maxY))
            path.close()
            return path
        case .line, .arrow, .doubleArrow:
            let path = UIBezierPath()
            path.move(to: lineStartInBounds)
            path.addLine(to: lineEndInBounds)
            return path
        }
    }

    private func lineInteractionPath() -> UIBezierPath {
        let path = UIBezierPath(cgPath: lineShapePath().cgPath)
        let hitWidth = max(lineWidth + 16, 24)
        let strokedPath = path.cgPath.copy(
            strokingWithWidth: hitWidth,
            lineCap: .round,
            lineJoin: .round,
            miterLimit: 10
        )
        return UIBezierPath(cgPath: strokedPath)
    }

    private func lineShapePath() -> UIBezierPath {
        let start = lineStartInBounds
        let end = lineEndInBounds
        let path = UIBezierPath()
        path.move(to: start)
        path.addLine(to: end)

        guard shapeKind == .arrow || shapeKind == .doubleArrow else { return path }

        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = hypot(dx, dy)
        guard length > 1 else { return path }

        let angle = atan2(dy, dx)
        let headLength = max(lineWidth * 5, 18)
        let headAngle: CGFloat = .pi / 6
        let firstPoint = CGPoint(
            x: end.x - headLength * cos(angle - headAngle),
            y: end.y - headLength * sin(angle - headAngle)
        )
        let secondPoint = CGPoint(
            x: end.x - headLength * cos(angle + headAngle),
            y: end.y - headLength * sin(angle + headAngle)
        )

        path.move(to: firstPoint)
        path.addLine(to: end)
        path.addLine(to: secondPoint)

        if shapeKind == .doubleArrow {
            let backAngle = angle + .pi
            let thirdPoint = CGPoint(
                x: start.x - headLength * cos(backAngle - headAngle),
                y: start.y - headLength * sin(backAngle - headAngle)
            )
            let fourthPoint = CGPoint(
                x: start.x - headLength * cos(backAngle + headAngle),
                y: start.y - headLength * sin(backAngle + headAngle)
            )
            path.move(to: thirdPoint)
            path.addLine(to: start)
            path.addLine(to: fourthPoint)
        }

        return path
    }

    override func draw(_ rect: CGRect) {
        strokeColor.setStroke()
        switch shapeKind {
        case .circle:
            let path = UIBezierPath(ovalIn: bounds.insetBy(dx: lineWidth / 2, dy: lineWidth / 2))
            path.lineWidth = lineWidth
            path.lineCapStyle = .round; path.lineJoinStyle = .round
            path.stroke()
        case .rectangle:
            let path = UIBezierPath(roundedRect: bounds.insetBy(dx: lineWidth / 2, dy: lineWidth / 2), cornerRadius: 4)
            path.lineWidth = lineWidth
            path.lineCapStyle = .round; path.lineJoinStyle = .round
            path.stroke()
        case .triangle:
            let r = bounds.insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
            let path = UIBezierPath()
            path.move(to:    CGPoint(x: r.midX, y: r.minY))
            path.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
            path.addLine(to: CGPoint(x: r.minX, y: r.maxY))
            path.close()
            path.lineWidth = lineWidth
            path.lineCapStyle = .round; path.lineJoinStyle = .round
            path.stroke()
        case .line:
            let path = UIBezierPath()
            path.move(to: lineStartInBounds)
            path.addLine(to: lineEndInBounds)
            path.lineWidth = lineWidth
            path.lineCapStyle = .round
            path.stroke()
        case .arrow:
            let start = lineStartInBounds
            let end   = lineEndInBounds
            let shaft = UIBezierPath()
            shaft.move(to: start)
            shaft.addLine(to: end)
            shaft.lineWidth = lineWidth
            shaft.lineCapStyle = .round
            shaft.stroke()
            drawArrowhead(from: start, to: end)
        case .doubleArrow:
            let start = lineStartInBounds
            let end   = lineEndInBounds
            let shaft = UIBezierPath()
            shaft.move(to: start)
            shaft.addLine(to: end)
            shaft.lineWidth = lineWidth
            shaft.lineCapStyle = .round
            shaft.stroke()
            drawArrowhead(from: start, to: end)
            drawArrowhead(from: end, to: start)
        }
    }

    private func drawArrowhead(from start: CGPoint, to end: CGPoint) {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let len = hypot(dx, dy)
        guard len > 1 else { return }
        let angle = atan2(dy, dx)
        let headLen = max(lineWidth * 5, 18)
        let headAngle: CGFloat = .pi / 6   // 30°
        let p1 = CGPoint(x: end.x - headLen * cos(angle - headAngle),
                         y: end.y - headLen * sin(angle - headAngle))
        let p2 = CGPoint(x: end.x - headLen * cos(angle + headAngle),
                         y: end.y - headLen * sin(angle + headAngle))
        let path = UIBezierPath()
        path.move(to: p1)
        path.addLine(to: end)
        path.addLine(to: p2)
        path.lineWidth = lineWidth
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.stroke()
    }

    func applyStyle(kind: OverlayShapeKind? = nil, strokeColor: UIColor, lineWidth: CGFloat) {
        if let kind { self.shapeKind = kind }
        self.strokeColor = strokeColor
        self.lineWidth = lineWidth
        setNeedsDisplay()
        setNeedsLayout()
    }

    func setSelectMode(_ enabled: Bool) {
        isSelectMode = enabled
        if !enabled { isSelected = false }
        pinchGesture?.isEnabled = enabled && !isLineKind
        updateHandleVisibility()
    }

    func setSelected(_ selected: Bool) {
        isSelected = selected
        updateHandleVisibility()
    }

    private func updateHandleVisibility() {
        let alpha: CGFloat = (isSelectMode && isSelected) ? 1.0 : 0.0
        moveHandle.alpha = alpha
        resizeHitTarget.alpha = alpha
        selectionBorderLayer.isHidden = !(isSelectMode && isSelected)
    }

    private func currentState(frame: CGRect? = nil) -> OverlayShapeState {
        OverlayShapeState(
            id: id, frame: frame ?? self.frame,
            kind: shapeKind, strokeColor: strokeColor, lineWidth: lineWidth,
            lineFlippedH: lineFlippedH, lineFlippedV: lineFlippedV
        )
    }

    static func lineDrawingInset(for kind: OverlayShapeKind, lineWidth: CGFloat) -> CGFloat {
        guard kind == .line || kind == .arrow || kind == .doubleArrow else { return 0 }
        let strokeInset = max(lineWidth / 2, 1)
        guard kind == .arrow || kind == .doubleArrow else { return strokeInset }
        let arrowHeadInset = max(lineWidth * 5, 18) * 0.5 + strokeInset
        return max(strokeInset, arrowHeadInset)
    }

    @objc private func handleSelect() {
        guard isSelectMode else { return }
        isSelected = true
        superview?.bringSubviewToFront(self)
        onSelect?(id)
        updateHandleVisibility()
    }

    // For line/arrow: moves the START endpoint. For others: moves the whole shape.
    @objc private func handleMovePan(_ gesture: UIPanGestureRecognizer) {
        guard isSelectMode else { return }
        guard let container = superview else { return }
        let translation = gesture.translation(in: container)
        switch gesture.state {
        case .began:
            startFrame = frame
            startLineFlippedH = lineFlippedH
            startLineFlippedV = lineFlippedV
            isSelected = true; onSelect?(id); updateHandleVisibility()
        case .changed:
            if isLineKind {
                moveLineEndpoint(isStart: true, dx: translation.x, dy: translation.y, in: container)
            } else {
                var f = frame.offsetBy(dx: translation.x, dy: translation.y)
                f.origin.x = max(0, min(f.origin.x, container.bounds.width  - f.width))
                f.origin.y = max(0, min(f.origin.y, container.bounds.height - f.height))
                frame = f
            }
            gesture.setTranslation(.zero, in: container)
        case .ended, .cancelled:
            let before = OverlayShapeState(id: id, frame: startFrame, kind: shapeKind,
                strokeColor: strokeColor, lineWidth: lineWidth,
                lineFlippedH: startLineFlippedH, lineFlippedV: startLineFlippedV)
            let after = currentState()
            if before.frame != after.frame || before.lineFlippedH != after.lineFlippedH || before.lineFlippedV != after.lineFlippedV {
                onEndChange?(before, after)
            }
        default: break
        }
    }

    @objc private func handleBodyMovePan(_ gesture: UIPanGestureRecognizer) {
        guard isSelectMode else { return }
        guard let container = superview else { return }
        let translation = gesture.translation(in: container)
        switch gesture.state {
        case .began:
            startFrame = frame
            startLineFlippedH = lineFlippedH
            startLineFlippedV = lineFlippedV
            isSelected = true; onSelect?(id)
            superview?.bringSubviewToFront(self); updateHandleVisibility()
        case .changed:
            var f = frame.offsetBy(dx: translation.x, dy: translation.y)
            f.origin.x = max(0, min(f.origin.x, container.bounds.width  - f.width))
            f.origin.y = max(0, min(f.origin.y, container.bounds.height - f.height))
            frame = f
            gesture.setTranslation(.zero, in: container)
        case .ended, .cancelled:
            let before = OverlayShapeState(id: id, frame: startFrame, kind: shapeKind,
                strokeColor: strokeColor, lineWidth: lineWidth,
                lineFlippedH: startLineFlippedH, lineFlippedV: startLineFlippedV)
            let after = currentState()
            if before.frame != after.frame { onEndChange?(before, after) }
        default: break
        }
    }

    // For line/arrow: moves the END endpoint. For others: resizes from bottom-right corner.
    @objc private func handleResizePan(_ gesture: UIPanGestureRecognizer) {
        guard isSelectMode else { return }
        guard let container = superview else { return }
        let translation = gesture.translation(in: container)
        switch gesture.state {
        case .began:
            startFrame = frame
            startLineFlippedH = lineFlippedH
            startLineFlippedV = lineFlippedV
            isSelected = true; onSelect?(id)
            resizeFeedback.prepare(); resizeFeedback.impactOccurred()
            UIView.animate(withDuration: 0.15, delay: 0, options: [.allowUserInteraction, .curveEaseOut]) {
                self.resizeHandleVisual.transform = CGAffineTransform(scaleX: 1.18, y: 1.18)
            }
            updateHandleVisibility()
        case .changed:
            if isLineKind {
                moveLineEndpoint(isStart: false, dx: translation.x, dy: translation.y, in: container)
            } else {
                var newSize = CGSize(
                    width:  max(minSize.width,  frame.width  + translation.x),
                    height: max(minSize.height, frame.height + translation.y)
                )
                if frame.origin.x + newSize.width  > container.bounds.width  { newSize.width  = container.bounds.width  - frame.origin.x }
                if frame.origin.y + newSize.height > container.bounds.height { newSize.height = container.bounds.height - frame.origin.y }
                frame = CGRect(origin: frame.origin, size: newSize)
            }
            gesture.setTranslation(.zero, in: container)
        case .ended, .cancelled:
            UIView.animate(withDuration: 0.2, delay: 0, options: [.allowUserInteraction, .curveEaseOut]) {
                self.resizeHandleVisual.transform = .identity
            }
            let before = OverlayShapeState(id: id, frame: startFrame, kind: shapeKind,
                strokeColor: strokeColor, lineWidth: lineWidth,
                lineFlippedH: startLineFlippedH, lineFlippedV: startLineFlippedV)
            let after = currentState()
            if before.frame != after.frame || before.lineFlippedH != after.lineFlippedH || before.lineFlippedV != after.lineFlippedV {
                onEndChange?(before, after)
            }
        default: break
        }
    }

    /// Moves one endpoint of the line/arrow by (dx, dy) in container coordinates.
    private func moveLineEndpoint(isStart: Bool, dx: CGFloat, dy: CGFloat, in container: UIView) {
        // Compute current endpoints in container space
        let startInBounds = lineStartInBounds
        let endInBounds = lineEndInBounds
        let startPt = CGPoint(
            x: frame.minX + startInBounds.x,
            y: frame.minY + startInBounds.y
        )
        let endPt = CGPoint(
            x: frame.minX + endInBounds.x,
            y: frame.minY + endInBounds.y
        )
        var movingPt  = isStart ? startPt : endPt
        let fixedPt   = isStart ? endPt   : startPt
        movingPt.x = max(0, min(movingPt.x + dx, container.bounds.width))
        movingPt.y = max(0, min(movingPt.y + dy, container.bounds.height))

        let newStart = isStart ? movingPt : fixedPt
        let newEnd   = isStart ? fixedPt  : movingPt
        let drawingInset = lineDrawingInset
        let newFrame = CGRect(
            x: min(newStart.x, newEnd.x) - drawingInset,
            y: min(newStart.y, newEnd.y) - drawingInset,
            width: max(abs(newEnd.x - newStart.x), minLineSize.width) + drawingInset * 2,
            height: max(abs(newEnd.y - newStart.y), minLineSize.height) + drawingInset * 2
        )
        frame = newFrame
        lineFlippedH = newStart.x > newEnd.x
        lineFlippedV = newStart.y > newEnd.y
        setNeedsDisplay()
    }

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard isSelectMode, !isLineKind else { return }
        guard let container = superview else { return }
        switch gesture.state {
        case .began:
            pinchStartFrame = frame; startFrame = frame
            startLineFlippedH = lineFlippedH; startLineFlippedV = lineFlippedV
            isSelected = true; onSelect?(id)
            superview?.bringSubviewToFront(self); updateHandleVisibility()
        case .changed:
            let scale = gesture.scale
            let center = CGPoint(x: pinchStartFrame.midX, y: pinchStartFrame.midY)
            var newW = max(minSize.width,  pinchStartFrame.width  * scale)
            var newH = max(minSize.height, pinchStartFrame.height * scale)
            var newX = center.x - newW / 2
            var newY = center.y - newH / 2
            newX = max(0, min(newX, container.bounds.width  - newW))
            newY = max(0, min(newY, container.bounds.height - newH))
            newW = min(newW, container.bounds.width  - newX)
            newH = min(newH, container.bounds.height - newY)
            newW = max(minSize.width, newW); newH = max(minSize.height, newH)
            frame = CGRect(x: newX, y: newY, width: newW, height: newH)
        case .ended, .cancelled:
            let before = OverlayShapeState(id: id, frame: startFrame, kind: shapeKind,
                strokeColor: strokeColor, lineWidth: lineWidth,
                lineFlippedH: startLineFlippedH, lineFlippedV: startLineFlippedV)
            let after = currentState()
            if before.frame != after.frame { onEndChange?(before, after) }
        default: break
        }
    }
}

extension DrawingPDFView {
    typealias ElementIdentifier = String
    
    func indirectScribbleInteraction(
        _ interaction: UIInteraction,
        isElementFocused elementIdentifier: ElementIdentifier
    ) -> Bool {
        return false
    }
    
    func indirectScribbleInteraction(
        _ interaction: UIInteraction,
        requestElementsIn rect: CGRect,
        completion: @escaping ([ElementIdentifier]) -> Void
    ) {
        guard let document = self.document else {
            completion([])
            return
        }
        
        var elementIDs: [String] = []
        
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            
            for annotation in page.annotations {
                if annotation.widgetFieldType == .text,
                   let fieldName = annotation.fieldName {
                    
                    // Convert annotation bounds to view coordinates
                    let pageBounds = annotation.bounds
                    let viewBounds = self.convert(pageBounds, from: page)
                    
                    if viewBounds.intersects(rect) {
                        elementIDs.append(fieldName)
                    }
                }
            }
        }
        
        completion(elementIDs)
    }
    
    func indirectScribbleInteraction(
        _ interaction: UIInteraction,
        frameForElement elementIdentifier: ElementIdentifier
    ) -> CGRect {
        guard let document = self.document else { return .zero }
        
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            
            for annotation in page.annotations {
                if annotation.fieldName == elementIdentifier {
                    return self.convert(annotation.bounds, from: page)
                }
            }
        }
        return .zero
    }
    
    func indirectScribbleInteraction(
        _ interaction: UIInteraction,
        focusElementIfNeeded elementIdentifier: ElementIdentifier,
        referencePoint focusReferencePoint: CGPoint,
        completion: @escaping ((UIResponder & UITextInput)?) -> Void
    ) {
        guard let document = self.document else {
            completion(nil)
            return
        }
        
        // Find and activate the PDF form field
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            
            for annotation in page.annotations {
                if annotation.fieldName == elementIdentifier {
                    // Use PDFView's built-in mechanism to focus the field
                    self.go(to: annotation.bounds, on: page)
                    
                    // Give PDFView a moment to create the text field, then find it
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        // Walk the view hierarchy to find the active UITextField
                        let textInput = self.findActiveTextInput()
                        completion(textInput)
                    }
                    return
                }
            }
        }
        completion(nil)
    }
    
    // Helper to find the focused UITextField/UITextView in PDFView's hierarchy
    private func findActiveTextInput() -> (UIResponder & UITextInput)? {
        return findTextInput(in: self)
    }
    
    private func findTextInput(in view: UIView) -> (UIResponder & UITextInput)? {
        if let textField = view as? UITextField, textField.isFirstResponder {
            return textField
        }
        if let textView = view as? UITextView, textView.isFirstResponder {
            return textView
        }
        for subview in view.subviews {
            if let found = findTextInput(in: subview) {
                return found
            }
        }
        return nil
    }
}

extension CGPath {
    func forEach(_ body: @escaping (CGPathElement) -> Void) {
        let body = body
        applyWithBlock { elementPointer in
            body(elementPointer.pointee)
        }
    }
}

extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        hypot(x - other.x, y - other.y)
    }
}




// MARK: - Preview
#Preview {
    PDFEditorHomeView()
}
