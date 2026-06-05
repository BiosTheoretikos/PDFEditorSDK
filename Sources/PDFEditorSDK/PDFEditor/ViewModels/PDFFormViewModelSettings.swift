//
//  PDFFormViewModelSettings.swift
//  PDFEditorSDK
//

import SwiftUI
import PDFKit
import UIKit

struct DrawingAnnotationSettings {
    var inkColor: UIColor
    var lineWidth: CGFloat
    var eraserRadius: CGFloat

    init(preferences: EditorPreferences) {
        inkColor = preferences.inkColor.uiColor
        lineWidth = preferences.inkLineWidth
        eraserRadius = preferences.eraserRadius
    }

    func apply(to preferences: inout EditorPreferences) {
        preferences.inkColor = RGBAColor(inkColor)
        preferences.inkLineWidth = lineWidth
        preferences.eraserRadius = eraserRadius
    }
}

struct TextAnnotationSettings {
    var backgroundColor: UIColor
    var fontSize: CGFloat
    var isBold: Bool
    var textColor: UIColor
    var textAlignment: NSTextAlignment
    var verticalAlignment: TextVerticalAlignment
    var borderWidth: CGFloat
    var borderColor: UIColor

    init(preferences: EditorPreferences) {
        backgroundColor = preferences.textBoxBackgroundColor.uiColor
        fontSize = max(1, preferences.textBoxFontSize)
        isBold = preferences.textBoxIsBold
        textColor = preferences.textBoxTextColor.uiColor
        textAlignment = NSTextAlignment(rawValue: preferences.textBoxTextAlignment) ?? .left
        verticalAlignment = TextVerticalAlignment(rawValue: preferences.textBoxVerticalAlignment) ?? .top
        borderWidth = preferences.textBoxBorderWidth
        borderColor = preferences.textBoxBorderColor.uiColor
    }

    mutating func normalize() {
        fontSize = max(1, fontSize)
    }

    func apply(to preferences: inout EditorPreferences) {
        preferences.textBoxBackgroundColor = RGBAColor(backgroundColor)
        preferences.textBoxFontSize = fontSize
        preferences.textBoxIsBold = isBold
        preferences.textBoxTextColor = RGBAColor(textColor)
        preferences.textBoxTextAlignment = textAlignment.rawValue
        preferences.textBoxVerticalAlignment = verticalAlignment.rawValue
        preferences.textBoxBorderWidth = borderWidth
        preferences.textBoxBorderColor = RGBAColor(borderColor)
    }
}

struct TextBoxBorderSelectionSettings {
    var width: CGFloat = 0
    var color: UIColor = .black
}

struct ShapeAnnotationSettings {
    var kind: OverlayShapeKind
    var strokeColor: UIColor
    var lineWidth: CGFloat

    init(preferences: EditorPreferences) {
        kind = preferences.activeShapeKind
        strokeColor = preferences.shapeStrokeColor.uiColor
        lineWidth = preferences.shapeLineWidth
    }

    func apply(to preferences: inout EditorPreferences) {
        preferences.activeShapeKind = kind
        preferences.shapeStrokeColor = RGBAColor(strokeColor)
        preferences.shapeLineWidth = lineWidth
    }
}

struct ImageAnnotationSettings {
    var borderWidth: CGFloat
    var borderColor: UIColor

    init(preferences: EditorPreferences) {
        borderWidth = preferences.imageBorderWidth
        borderColor = preferences.imageBorderColor.uiColor
    }

    func apply(to preferences: inout EditorPreferences) {
        preferences.imageBorderWidth = borderWidth
        preferences.imageBorderColor = RGBAColor(borderColor)
    }
}

struct PencilInputSettings {
    var drawWithFinger: Bool
    var pencilOnlyAnnotations: Bool
    var doubleTapAction: PencilGestureAction
    var squeezeAction: PencilGestureAction
    var doubleSqueezeAction: PencilGestureAction

    init(preferences: EditorPreferences) {
        drawWithFinger = preferences.drawWithFinger
        pencilOnlyAnnotations = preferences.pencilOnlyAnnotations
        doubleTapAction = preferences.pencilDoubleTapAction
        squeezeAction = preferences.pencilSqueezeAction
        doubleSqueezeAction = preferences.pencilDoubleSqueezeAction
    }

    mutating func normalize() {
        if pencilOnlyAnnotations {
            drawWithFinger = false
        }
    }

    func apply(to preferences: inout EditorPreferences) {
        preferences.drawWithFinger = drawWithFinger
        preferences.pencilOnlyAnnotations = pencilOnlyAnnotations
        preferences.pencilDoubleTapAction = doubleTapAction
        preferences.pencilSqueezeAction = squeezeAction
        preferences.pencilDoubleSqueezeAction = doubleSqueezeAction
    }
}

struct EditorDisplaySettings {
    var isThumbnailOverlayVisible: Bool

    init(preferences: EditorPreferences) {
        isThumbnailOverlayVisible = preferences.isThumbnailOverlayVisible
    }

    func apply(to preferences: inout EditorPreferences) {
        preferences.isThumbnailOverlayVisible = isThumbnailOverlayVisible
    }
}

struct LineWidthControlSettings {
    var step: CGFloat
    var max: CGFloat

    init(preferences: EditorPreferences) {
        step = preferences.lineWidthStep
        max = preferences.lineWidthMax
        normalize()
    }

    mutating func normalize() {
        let steps: [CGFloat] = [0.25, 0.5, 1]
        step = steps.min { abs($0 - step) < abs($1 - step) } ?? 0.5

        let maxAllowed: [CGFloat] = [12, 24, 36, 48]
        max = maxAllowed.min { abs($0 - max) < abs($1 - max) } ?? 24
    }

    func apply(to preferences: inout EditorPreferences) {
        preferences.lineWidthStep = step
        preferences.lineWidthMax = max
    }
}
