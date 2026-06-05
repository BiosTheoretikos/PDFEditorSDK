import SwiftUI
import UIKit

struct DrawingImageViewRepresentable: UIViewRepresentable {
    @Bindable var viewModel: ImageEditorViewModel

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 5.0
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.delegate = context.coordinator

        let drawingView = DrawingImageView()
        drawingView.viewModel = viewModel
        viewModel.canvasView = drawingView
        drawingView.setSourceImage(viewModel.sourceImage)
        drawingView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(drawingView)

        NSLayoutConstraint.activate([
            drawingView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            drawingView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            drawingView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            drawingView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            drawingView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            drawingView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),
        ])

        context.coordinator.drawingView = drawingView
        context.coordinator.scrollView = scrollView

        updateScrollGestureRequirements(
            scrollView,
            isSelectMode: viewModel.isSelectMode,
            pencilOnlyAnnotations: viewModel.pencilOnlyAnnotations
        )

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        guard let view = context.coordinator.drawingView else { return }

        view.isDrawingMode = viewModel.isDrawingMode
        view.isTextMode = viewModel.isTextMode
        view.isSelectMode = viewModel.isSelectMode
        view.currentInkColor = viewModel.inkColor
        view.currentLineWidth = viewModel.inkLineWidth
        view.isEraserMode = viewModel.isEraserMode
        view.eraserRadius = viewModel.eraserRadius
        view.textBoxBackgroundColor = viewModel.textBoxBackgroundColor
        view.textBoxFontSize = viewModel.textBoxFontSize
        view.textBoxIsBold = viewModel.textBoxIsBold
        view.textBoxTextColor = viewModel.textBoxTextColor
        view.textBoxTextAlignment = viewModel.textBoxTextAlignment
        view.textBoxVerticalAlignment = viewModel.textBoxVerticalAlignment
        view.textBoxBorderWidth = viewModel.textBoxBorderWidth
        view.textBoxBorderColor = viewModel.textBoxBorderColor
        view.isShapeMode = viewModel.activeTool == .shape
        view.currentShapeKind = viewModel.activeShapeKind
        view.shapeStrokeColor = viewModel.shapeStrokeColor
        view.shapeLineWidth = viewModel.shapeLineWidth
        view.isPencilKitMode = viewModel.activeTool == .pencilKit
        view.currentImageBorderWidth = viewModel.imageBorderWidth
        view.currentImageBorderColor = viewModel.imageBorderColor
        view.drawWithFinger = viewModel.drawWithFinger
        view.pencilOnlyAnnotations = viewModel.pencilOnlyAnnotations

        updateScrollGestureRequirements(
            scrollView,
            isSelectMode: viewModel.isSelectMode,
            pencilOnlyAnnotations: viewModel.pencilOnlyAnnotations
        )
    }

    private func updateScrollGestureRequirements(
        _ scrollView: UIScrollView,
        isSelectMode: Bool,
        pencilOnlyAnnotations: Bool
    ) {
        let requiresTwoFingers = !isSelectMode && !pencilOnlyAnnotations
        scrollView.panGestureRecognizer.minimumNumberOfTouches = requiresTwoFingers ? 2 : 1
        scrollView.panGestureRecognizer.maximumNumberOfTouches = 2
        scrollView.panGestureRecognizer.allowedTouchTypes = pencilOnlyAnnotations
            ? [NSNumber(value: UITouch.TouchType.direct.rawValue)]
            : [NSNumber(value: UITouch.TouchType.direct.rawValue),
               NSNumber(value: UITouch.TouchType.pencil.rawValue)]
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        weak var drawingView: DrawingImageView?
        weak var scrollView: UIScrollView?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            drawingView
        }
    }
}
