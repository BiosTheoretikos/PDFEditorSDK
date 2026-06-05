//
//  ImageBoxView.swift
//  PDFEditorSDK
//

import SwiftUI
import PDFKit
import UIKit

final class ImageBoxView: UIView {
    private let imageView = UIImageView()
    private let moveHandle = UIView()
    private let moveIcon = UIImageView()
    private let resizeHitTarget = ResizeHandleHitTargetView()
    private let resizeHandleVisual = UIView()
    private let resizeIcon = UIImageView()
    private var pinchGesture: UIPinchGestureRecognizer?
    private let resizeFeedback = UIImpactFeedbackGenerator(style: .light)
    private let minSize = CGSize(width: 80, height: 80)
    private let resizeVisualSize: CGFloat = 24
    private var pinchStartFrame: CGRect = .zero
    
    let id: UUID
    var imageData: Data
    var imageBorderWidth: CGFloat = 0
    var imageBorderColor: UIColor = .black
    var onSelect: ((UUID) -> Void)?
    var onEndChange: ((OverlayImageState, OverlayImageState) -> Void)?
    private var startFrame: CGRect = .zero
    private var isSelectMode: Bool = false
    private var isSelected: Bool = false

    init(id: UUID, imageData: Data) {
        self.id = id
        self.imageData = imageData
        super.init(frame: .zero)
        setup()
        setImageData(imageData)
    }
    
    required init?(coder: NSCoder) {
        self.id = UUID()
        self.imageData = Data()
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        layer.cornerRadius = 6
        clipsToBounds = true
        applyImageBorder()

        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .clear
        addSubview(imageView)
        
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
        
        let bodyMovePan = UIPanGestureRecognizer(target: self, action: #selector(handleBodyMovePan(_:)))
        addGestureRecognizer(bodyMovePan)
        
        let resizePan = UIPanGestureRecognizer(target: self, action: #selector(handleResizePan(_:)))
        resizeHitTarget.addGestureRecognizer(resizePan)
        
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinchGesture = pinch
        addGestureRecognizer(pinch)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleSelect))
        addGestureRecognizer(tap)
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        overlayHitTestForwardingOutOfBounds(host: self, point: point, event: event) { p, e in
            super.hitTest(p, with: e)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = bounds
        
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
    }
    
    func setImageData(_ data: Data) {
        imageData = data
        imageView.image = UIImage(data: data)
    }

    func updateBorder(width: CGFloat, color: UIColor) {
        imageBorderWidth = width
        imageBorderColor = color
        applyImageBorder()
    }

    private func applyImageBorder() {
        layer.borderWidth = imageBorderWidth > 0 ? imageBorderWidth : 0
        layer.borderColor = imageBorderWidth > 0 ? imageBorderColor.cgColor : UIColor.clear.cgColor
    }

    func setSelectMode(_ enabled: Bool) {
        isSelectMode = enabled
        if !enabled {
            isSelected = false
        }
        let alpha: CGFloat = (enabled && isSelected) ? 1.0 : 0.0
        moveHandle.alpha = alpha
        resizeHitTarget.alpha = alpha
        pinchGesture?.isEnabled = enabled
        if !enabled {
            resizeHandleVisual.transform = .identity
        }
        if enabled && isSelected {
            layer.borderWidth = max(imageBorderWidth, 1)
            layer.borderColor = UIColor.systemBlue.cgColor
        } else {
            applyImageBorder()
        }
    }

    func setSelected(_ selected: Bool) {
        isSelected = selected
        setSelectMode(isSelectMode)
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
        switch gesture.state {
        case .began:
            startFrame = frame
            isSelected = true
            onSelect?(id)
        case .changed:
            var newFrame = frame.offsetBy(dx: translation.x, dy: translation.y)
            newFrame.origin.x = max(0, min(newFrame.origin.x, container.bounds.width - newFrame.width))
            newFrame.origin.y = max(0, min(newFrame.origin.y, container.bounds.height - newFrame.height))
            frame = newFrame
            gesture.setTranslation(.zero, in: container)
        case .ended, .cancelled:
            let before = OverlayImageState(id: id, frame: startFrame, imageData: imageData, borderWidth: imageBorderWidth, borderColor: imageBorderColor)
            let after = OverlayImageState(id: id, frame: frame, imageData: imageData, borderWidth: imageBorderWidth, borderColor: imageBorderColor)
            onEndChange?(before, after)
        default:
            break
        }
    }
    
    @objc private func handleBodyMovePan(_ gesture: UIPanGestureRecognizer) {
        guard isSelectMode else { return }
        guard let container = superview else { return }
        let translation = gesture.translation(in: container)
        switch gesture.state {
        case .began:
            startFrame = frame
            isSelected = true
            onSelect?(id)
            superview?.bringSubviewToFront(self)
        case .changed:
            var newFrame = frame.offsetBy(dx: translation.x, dy: translation.y)
            newFrame.origin.x = max(0, min(newFrame.origin.x, container.bounds.width - newFrame.width))
            newFrame.origin.y = max(0, min(newFrame.origin.y, container.bounds.height - newFrame.height))
            frame = newFrame
            gesture.setTranslation(.zero, in: container)
        case .ended, .cancelled:
            let before = OverlayImageState(id: id, frame: startFrame, imageData: imageData, borderWidth: imageBorderWidth, borderColor: imageBorderColor)
            let after = OverlayImageState(id: id, frame: frame, imageData: imageData, borderWidth: imageBorderWidth, borderColor: imageBorderColor)
            if before.frame != after.frame {
                onEndChange?(before, after)
            }
        default:
            break
        }
    }
    
    @objc private func handleResizePan(_ gesture: UIPanGestureRecognizer) {
        guard isSelectMode else { return }
        guard let container = superview else { return }
        let translation = gesture.translation(in: container)
        switch gesture.state {
        case .began:
            startFrame = frame
            isSelected = true
            onSelect?(id)
            resizeFeedback.prepare()
            resizeFeedback.impactOccurred()
            UIView.animate(withDuration: 0.15, delay: 0, options: [.allowUserInteraction, .curveEaseOut]) {
                self.resizeHandleVisual.transform = CGAffineTransform(scaleX: 1.18, y: 1.18)
            }
        case .changed:
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
        case .ended, .cancelled:
            UIView.animate(withDuration: 0.2, delay: 0, options: [.allowUserInteraction, .curveEaseOut]) {
                self.resizeHandleVisual.transform = .identity
            }
            let before = OverlayImageState(id: id, frame: startFrame, imageData: imageData, borderWidth: imageBorderWidth, borderColor: imageBorderColor)
            let after = OverlayImageState(id: id, frame: frame, imageData: imageData, borderWidth: imageBorderWidth, borderColor: imageBorderColor)
            if before.frame != after.frame {
                onEndChange?(before, after)
            }
        default:
            break
        }
    }
    
    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard isSelectMode else { return }
        guard let container = superview else { return }
        switch gesture.state {
        case .began:
            pinchStartFrame = frame
            startFrame = frame
            isSelected = true
            onSelect?(id)
            superview?.bringSubviewToFront(self)
        case .changed:
            let scale = gesture.scale
            let center = CGPoint(x: pinchStartFrame.midX, y: pinchStartFrame.midY)
            var newW = max(minSize.width, pinchStartFrame.width * scale)
            var newH = max(minSize.height, pinchStartFrame.height * scale)
            var newX = center.x - newW / 2
            var newY = center.y - newH / 2
            newX = max(0, min(newX, container.bounds.width - newW))
            newY = max(0, min(newY, container.bounds.height - newH))
            newW = min(newW, container.bounds.width - newX)
            newH = min(newH, container.bounds.height - newY)
            newW = max(minSize.width, newW)
            newH = max(minSize.height, newH)
            frame = CGRect(x: newX, y: newY, width: newW, height: newH)
        case .ended, .cancelled:
            let before = OverlayImageState(id: id, frame: startFrame, imageData: imageData, borderWidth: imageBorderWidth, borderColor: imageBorderColor)
            let after = OverlayImageState(id: id, frame: frame, imageData: imageData, borderWidth: imageBorderWidth, borderColor: imageBorderColor)
            if before.frame != after.frame {
                onEndChange?(before, after)
            }
        default:
            break
        }
    }
}

// MARK: - ShapeBoxView

