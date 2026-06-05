//
//  OverlayViews.swift
//  PDFEditorSDK
//
//  Extracted from PDFEditorView.swift
//

import SwiftUI
import PDFKit
import UIKit

/// Default `UIView.hitTest` ignores touches outside the view’s `bounds`, so subviews laid out past the edge (move/resize handles) never receive them. Call `superHitTest` when the point is inside `bounds`; otherwise ask subviews in z-order.
func overlayHitTestForwardingOutOfBounds(
    host: UIView,
    point: CGPoint,
    event: UIEvent?,
    superHitTest: (CGPoint, UIEvent?) -> UIView?
) -> UIView? {
    guard host.isUserInteractionEnabled, !host.isHidden, host.alpha > 0.01 else { return nil }
    if host.point(inside: point, with: event) {
        return superHitTest(point, event)
    }
    for sub in host.subviews.reversed() {
        guard sub.isUserInteractionEnabled, !sub.isHidden, sub.alpha > 0.01 else { continue }
        let p = sub.convert(point, from: host)
        if let hit = sub.hitTest(p, with: event) {
            return hit
        }
    }
    return nil
}
/// Expands the tappable region beyond the visible resize knob (UIKit hit-testing uses `point(inside:with:)`).
final class ResizeHandleHitTargetView: UIView {
    /// Extra points beyond the visible handle bounds that still count as a hit (easier to grab when resizing).
    static let expansion: CGFloat = 18
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        bounds.insetBy(dx: -Self.expansion, dy: -Self.expansion).contains(point)
    }
}
