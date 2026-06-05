//
//  PencilDrawingGestureRecognizer.swift
//  PDFEditorSDK
//

import UIKit

// MARK: - Pencil Drawing Gesture Recognizer

protocol PencilDrawingGestureDelegate: AnyObject {
    func pencilTouchBegan(_ touch: UITouch, with event: UIEvent?)
    func pencilTouchMoved(_ touch: UITouch, with event: UIEvent?)
    func pencilTouchEnded(_ touch: UITouch, with event: UIEvent?)
    func pencilTouchCancelled(with event: UIEvent?)
}

final class PencilDrawingGestureRecognizer: UIGestureRecognizer {
    weak var drawingDelegate: PencilDrawingGestureDelegate?

    /// When `true`, single-finger touches are also accepted for drawing in
    /// addition to Apple Pencil. Updating this property also updates
    /// `allowedTouchTypes` so UIKit routes the right events.
    var includesFingerInput: Bool = false {
        didSet {
            allowedTouchTypes = includesFingerInput
                ? [NSNumber(value: UITouch.TouchType.pencil.rawValue),
                   NSNumber(value: UITouch.TouchType.direct.rawValue)]
                : [NSNumber(value: UITouch.TouchType.pencil.rawValue)]
        }
    }

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        allowedTouchTypes = [NSNumber(value: UITouch.TouchType.pencil.rawValue)]
    }

    private func isValidTouch(_ touch: UITouch) -> Bool {
        touch.type == .pencil || (includesFingerInput && touch.type == .direct)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = touches.first, isValidTouch(touch) else {
            for touch in touches { ignore(touch, for: event) }
            return
        }
        state = .began
        drawingDelegate?.pencilTouchBegan(touch, with: event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = touches.first, isValidTouch(touch) else { return }
        state = .changed
        drawingDelegate?.pencilTouchMoved(touch, with: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = touches.first, isValidTouch(touch) else { return }
        state = .ended
        drawingDelegate?.pencilTouchEnded(touch, with: event)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        state = .cancelled
        drawingDelegate?.pencilTouchCancelled(with: event)
    }
}
