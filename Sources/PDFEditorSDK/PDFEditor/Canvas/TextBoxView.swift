//
//  TextBoxView.swift
//  PDFEditorSDK
//

import SwiftUI
import PDFKit
import UIKit

final class TextBoxView: UIView, UITextViewDelegate, UIScribbleInteractionDelegate {
    private let textView = UITextView()
    /// Added only while Scribble should be suppressed; `UITextView` has no `isScribbleEnabled` (unlike `UITextField`).
    private var scribbleSuppressionInteraction: UIScribbleInteraction?
    private let padding = UIEdgeInsets(top: 6, left: 8, bottom: 6, right: 8)
    /// True once the text contains an explicit newline (user pressed Return).
    /// While true, horizontal auto-expansion is suppressed — the width is fixed
    /// and only the height grows. Resets automatically if all newlines are removed.
    private var widthLockedByNewline = false
    private let moveHandle = UIView()
    private let moveIcon = UIImageView()
    private let resizeHitTarget = ResizeHandleHitTargetView()
    private let resizeHandleVisual = UIView()
    private let resizeIcon = UIImageView()
    private let resizeVisualSize: CGFloat = 24
    private var isSelected: Bool = false {
        didSet { updateSelectionUI() }
    }
    private var isSelectMode: Bool = false
    private let minSize = CGSize(width: 80, height: 40)
    var currentText: String { textView.text ?? "" }
    var currentBackgroundColor: UIColor { backgroundColor ?? .clear }
    var currentFontSize: CGFloat { textView.font?.pointSize ?? 14 }
    var currentTextColor: UIColor { textView.textColor ?? .label }
    var currentIsBold: Bool {
        textView.font?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? false
    }
    var currentTextAlignment: NSTextAlignment { textView.textAlignment }
    private var _verticalAlignment: TextVerticalAlignment = .top
    var currentVerticalAlignment: TextVerticalAlignment { _verticalAlignment }
    private var _borderWidth: CGFloat = 0
    private var _borderColor: UIColor = .black
    var currentBorderWidth: CGFloat { _borderWidth }
    var currentBorderColor: UIColor { _borderColor }
    private let overflowIndicator = UIImageView()
    var onSelect: ((UUID) -> Void)?
    /// Called when the embedded `UITextView` gains or loses first responder (keyboard show/hide).
    var onTextEditingFocusChange: (() -> Void)?
    let id: UUID
    private var startFrame: CGRect = .zero
    private var pinchStartFrame: CGRect = .zero
    private var bodyMovePan: UIPanGestureRecognizer?
    private var moveHandlePan: UIPanGestureRecognizer?
    private var resizeHandlePan: UIPanGestureRecognizer?
    private var pinchGesture: UIPinchGestureRecognizer?
    
    init(id: UUID) {
        self.id = id
        super.init(frame: .zero)
        setup()
    }
    
    required init?(coder: NSCoder) {
        self.id = UUID()
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        layer.zPosition = 1
        layer.cornerRadius = 6
        applyUserBorder()
        
        textView.backgroundColor = .clear
        textView.font = UIFont.systemFont(ofSize: 14)
        textView.textColor = .label
        textView.isScrollEnabled = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.delegate = self
        addSubview(textView)
        
        moveHandle.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.12)
        moveHandle.layer.cornerRadius = 6
        moveHandle.layer.borderWidth = 1
        moveHandle.layer.borderColor = UIColor.systemBlue.cgColor
        moveIcon.image = UIImage(systemName: "arrow.up.and.down.and.arrow.left.and.right")
        moveIcon.tintColor = UIColor.systemBlue
        moveIcon.contentMode = .scaleAspectFit
        moveHandle.addSubview(moveIcon)
        addSubview(moveHandle)
        
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
        moveHandlePan = movePan
        
        let bodyMovePan = UIPanGestureRecognizer(target: self, action: #selector(handleBodyMovePan(_:)))
        bodyMovePan.cancelsTouchesInView = false
        addGestureRecognizer(bodyMovePan)
        self.bodyMovePan = bodyMovePan
        
        let resizePan = UIPanGestureRecognizer(target: self, action: #selector(handleResizePan(_:)))
        resizeHitTarget.addGestureRecognizer(resizePan)
        resizeHandlePan = resizePan
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleSelect))
        addGestureRecognizer(tap)

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        addGestureRecognizer(pinch)
        pinchGesture = pinch

        let overflowSymbolConfig = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
            .applying(UIImage.SymbolConfiguration(paletteColors: [.systemBackground, .systemOrange]))
        overflowIndicator.image = UIImage(systemName: "exclamationmark.circle.fill",
                                          withConfiguration: overflowSymbolConfig)
        overflowIndicator.contentMode = .scaleAspectFit
        overflowIndicator.isHidden = true
        overflowIndicator.layer.zPosition = 3
        overflowIndicator.isUserInteractionEnabled = false
        addSubview(overflowIndicator)

        isSelected = true
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        overlayHitTestForwardingOutOfBounds(host: self, point: point, event: event) { p, e in
            super.hitTest(p, with: e)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        textView.frame = bounds.inset(by: padding)
        updateVerticalInset()

        let handleSize: CGFloat = 16
        moveHandle.frame = CGRect(x: -6, y: -6, width: handleSize, height: handleSize)
        moveIcon.frame = moveHandle.bounds.insetBy(dx: 2, dy: 2)
        let v = resizeVisualSize
        resizeHitTarget.frame = CGRect(
            x: bounds.width - v + 6,
            y: bounds.height - v + 6,
            width: v,
            height: v
        )
        resizeHandleVisual.frame = resizeHitTarget.bounds
        resizeIcon.frame = resizeHandleVisual.bounds.insetBy(dx: 3, dy: 3)

        let indicatorSize: CGFloat = 18
        overflowIndicator.frame = CGRect(
            x: (bounds.width - indicatorSize) / 2,
            y: bounds.height - indicatorSize * 0.55,
            width: indicatorSize,
            height: indicatorSize
        )
    }
    
    func setText(_ text: String) {
        textView.text = text
        widthLockedByNewline = text.contains("\n")
        autoExpandIfNeeded()
        updateVerticalInset()
    }

    func setBackground(_ color: UIColor) {
        backgroundColor = color
    }

    func setFontSize(_ size: CGFloat, isBold: Bool = false) {
        textView.font = isBold ? UIFont.boldSystemFont(ofSize: size) : UIFont.systemFont(ofSize: size)
        autoExpandIfNeeded()
        updateVerticalInset()
    }

    func updateBorder(width: CGFloat, color: UIColor) {
        _borderWidth = width
        _borderColor = color
        if isSelected {
            updateSelectionUI()
        } else {
            applyUserBorder()
        }
    }

    private func applyUserBorder() {
        guard !isSelected else { return }
        layer.borderWidth = _borderWidth > 0 ? _borderWidth : 0
        layer.borderColor = _borderWidth > 0 ? _borderColor.cgColor : UIColor.clear.cgColor
    }

    /// Grows the text box to fit its content when needed, but never shrinks it.
    ///
    /// **Auto-width mode** (no explicit newlines in the text): the box expands
    /// horizontally as content grows, up to the container's right edge, then wraps
    /// and grows vertically for additional lines.
    ///
    /// **Fixed-width mode** (text contains an explicit newline — user pressed Return):
    /// the width is frozen at its current value and only the height grows. The mode
    /// reverts to auto-width if the user removes all newlines.
    ///
    /// In both modes the box can only get larger; it never collapses below the size
    /// it was drawn at or last manually resized to.
    private func autoExpandIfNeeded() {
        guard let container = superview else { return }

        let resolvedWidth: CGFloat

        if widthLockedByNewline {
            // Fixed-width mode: honour the current width, don't grow horizontally.
            resolvedWidth = frame.width
        } else {
            // Auto-width mode: expand to fit content on one line, capped at the
            // container's right edge, but never shrink below the current width.
            let containerMaxWidth = container.bounds.width - frame.origin.x
            let clampedMaxWidth = max(minSize.width, containerMaxWidth)
            let singleLineFit = textView.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
            let idealWidth = ceil(singleLineFit.width) + padding.left + padding.right
            let contentFitWidth = max(minSize.width, min(idealWidth, clampedMaxWidth))
            resolvedWidth = max(frame.width, contentFitWidth)
        }

        // Height: measure at the resolved width so word-wrap is computed against
        // the actual box width (important when width is capped at the container edge).
        let textWidth = max(1, resolvedWidth - padding.left - padding.right)
        let heightFit = textView.sizeThatFits(CGSize(width: textWidth, height: CGFloat.greatestFiniteMagnitude))
        let contentFitHeight = max(minSize.height, ceil(heightFit.height) + padding.top + padding.bottom)
        let maxAllowedHeight = container.bounds.height - frame.origin.y
        let contentFitHeightClamped = min(contentFitHeight, maxAllowedHeight)
        // Never shrink below the current height.
        let resolvedHeight = max(frame.height, contentFitHeightClamped)

        let widthChanged = abs(resolvedWidth - frame.width) > 0.5
        let heightChanged = abs(resolvedHeight - frame.height) > 0.5
        guard widthChanged || heightChanged else { return }

        frame = CGRect(origin: frame.origin, size: CGSize(width: resolvedWidth, height: resolvedHeight))
    }
    
    func setTextColor(_ color: UIColor) {
        textView.textColor = color
    }

    func setTextAlignment(_ alignment: NSTextAlignment) {
        textView.textAlignment = alignment
    }

    func setVerticalAlignment(_ alignment: TextVerticalAlignment) {
        _verticalAlignment = alignment
        updateVerticalInset()
    }

    /// Adjusts `textContainerInset.top` so the text content sits at the
    /// correct vertical position within the text view frame.
    private func updateVerticalInset() {
        guard textView.frame.height > 0 else { return }
        let fitting = textView.sizeThatFits(CGSize(width: textView.frame.width, height: .greatestFiniteMagnitude))
        let contentHeight = fitting.height
        let available = textView.frame.height
        var topOffset: CGFloat = 0
        switch _verticalAlignment {
        case .top:
            topOffset = 0
        case .middle:
            topOffset = max(0, (available - contentHeight) / 2)
        case .bottom:
            topOffset = max(0, available - contentHeight)
        }
        textView.textContainerInset = UIEdgeInsets(top: topOffset, left: 0, bottom: 0, right: 0)
        updateOverflowIndicator()
    }

    private func updateOverflowIndicator() {
        guard textView.frame.width > 0, textView.frame.height > 0 else { return }
        let fitting = textView.sizeThatFits(
            CGSize(width: textView.frame.width, height: .greatestFiniteMagnitude)
        )
        let isOverflowing = fitting.height > textView.frame.height + 1
        overflowIndicator.isHidden = !isOverflowing
    }

    var isTextInputFirstResponder: Bool { textView.isFirstResponder }

    /// When `false`, Scribble is suppressed on this `UITextView` via `UIScribbleInteraction`.
    func setTextInputScribbleEnabled(_ enabled: Bool) {
        if enabled {
            if let interaction = scribbleSuppressionInteraction {
                textView.removeInteraction(interaction)
                scribbleSuppressionInteraction = nil
            }
        } else if scribbleSuppressionInteraction == nil {
            let interaction = UIScribbleInteraction(delegate: self)
            scribbleSuppressionInteraction = interaction
            textView.addInteraction(interaction)
        }
    }

    func scribbleInteraction(_ interaction: UIScribbleInteraction, shouldBeginAt location: CGPoint) -> Bool {
        false
    }
    
    func beginEditing() {
        textView.becomeFirstResponder()
    }

    func endEditingIfNeeded() {
        if textView.isFirstResponder {
            textView.resignFirstResponder()
        }
    }

    func hideCursorForExport() {
        textView.tintColor = .clear
    }

    func restoreCursorAfterExport() {
        textView.tintColor = nil
    }

    func setSelected(_ selected: Bool) {
        isSelected = selected
        updateSelectionUI()
    }
    
    func setSelectMode(_ enabled: Bool) {
        if enabled {
            endEditingIfNeeded()
        }
        isSelectMode = enabled
        textView.isEditable = !enabled
        bodyMovePan?.isEnabled = enabled
        moveHandlePan?.isEnabled = enabled
        resizeHandlePan?.isEnabled = enabled
        pinchGesture?.isEnabled = enabled
        if !enabled { isSelected = false }
        updateSelectionUI()
    }
    
    private func updateSelectionUI() {
        let alpha: CGFloat = (isSelectMode && isSelected) ? 1.0 : 0.0
        moveHandle.alpha = alpha
        resizeHitTarget.alpha = alpha
        if isSelectMode && isSelected {
            layer.borderWidth = max(_borderWidth, 1)
            layer.borderColor = UIColor.systemBlue.cgColor
        } else if isSelected {
            layer.borderWidth = max(_borderWidth, 1)
            layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.45).cgColor
        } else {
            applyUserBorder()
        }
    }
    
    @objc private func handleSelect() {
        guard isSelectMode else { return }
        isSelected = true
        superview?.bringSubviewToFront(self)
        onSelect?(id)
    }
    
    @objc private func handleMovePan(_ gesture: UIPanGestureRecognizer) {
        guard isSelectMode else { return }
        guard let container = superview else { return }
        let translation = gesture.translation(in: container)
        var newFrame = frame.offsetBy(dx: translation.x, dy: translation.y)
        newFrame.origin.x = max(0, min(newFrame.origin.x, container.bounds.width - newFrame.width))
        newFrame.origin.y = max(0, min(newFrame.origin.y, container.bounds.height - newFrame.height))
        frame = newFrame
        gesture.setTranslation(.zero, in: container)
    }
    
    @objc private func handleBodyMovePan(_ gesture: UIPanGestureRecognizer) {
        guard isSelectMode else { return }
        guard let container = superview else { return }
        let translation = gesture.translation(in: container)
        switch gesture.state {
        case .began:
            startFrame = frame
            isSelected = true
            superview?.bringSubviewToFront(self)
            onSelect?(id)
        case .changed:
            var newFrame = frame.offsetBy(dx: translation.x, dy: translation.y)
            newFrame.origin.x = max(0, min(newFrame.origin.x, container.bounds.width - newFrame.width))
            newFrame.origin.y = max(0, min(newFrame.origin.y, container.bounds.height - newFrame.height))
            frame = newFrame
            gesture.setTranslation(.zero, in: container)
        default:
            break
        }
    }
    
    @objc private func handleResizePan(_ gesture: UIPanGestureRecognizer) {
        guard let container = superview else { return }
        let translation = gesture.translation(in: container)
        var newSize = CGSize(
            width: max(minSize.width, frame.width + translation.x),
            height: max(minSize.height, frame.height + translation.y)
        )
        if frame.origin.x + newSize.width > container.bounds.width {
            newSize.width = container.bounds.width - frame.origin.x
        }
        if frame.origin.y + newSize.height > container.bounds.height {
            newSize.height = container.bounds.height - frame.origin.y
        }
        frame = CGRect(origin: frame.origin, size: newSize)
        gesture.setTranslation(.zero, in: container)
    }

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard isSelectMode, let container = superview else { return }
        switch gesture.state {
        case .began:
            pinchStartFrame = frame
            isSelected = true
            superview?.bringSubviewToFront(self)
            onSelect?(id)
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
            frame = CGRect(x: newX, y: newY, width: newW, height: newH)
        default:
            break
        }
    }
    
    func applyTextStyle(fontSize: CGFloat, isBold: Bool, textColor: UIColor) {
        let font = isBold ? UIFont.boldSystemFont(ofSize: fontSize) : UIFont.systemFont(ofSize: fontSize)
        if let range = textView.selectedTextRange, !range.isEmpty {
            let nsRange = textView.selectedRange
            let mutable = NSMutableAttributedString(attributedString: textView.attributedText ?? NSAttributedString(string: textView.text ?? ""))
            mutable.addAttribute(.font, value: font, range: nsRange)
            mutable.addAttribute(.foregroundColor, value: textColor, range: nsRange)
            textView.attributedText = mutable
            textView.selectedRange = nsRange
        } else {
            textView.font = font
            textView.textColor = textColor
        }
        textView.typingAttributes[.font] = font
        textView.typingAttributes[.foregroundColor] = textColor
        autoExpandIfNeeded()
        updateVerticalInset()
    }

    func textViewDidChange(_ textView: UITextView) {
        // Lock horizontal expansion once the user explicitly breaks a line.
        // Unlock if they remove all newlines and return to single-line text.
        widthLockedByNewline = textView.text?.contains("\n") ?? false
        autoExpandIfNeeded()
        updateVerticalInset()
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        isSelected = true
        onSelect?(id)
        onTextEditingFocusChange?()
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        onTextEditingFocusChange?()
    }
}
