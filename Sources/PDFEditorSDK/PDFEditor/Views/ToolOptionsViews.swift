//
//  ToolOptionsViews.swift
//  PDFEditorSDK
//

import SwiftUI
import UIKit

// MARK: - Draw Tool Options

struct DrawToolOptionsView: View {
    @Binding var inkColor: Color
    @Binding var inkLineWidth: CGFloat
    var lineWidthStep: CGFloat
    var lineWidthMax: CGFloat

    var body: some View {
        Form {
            Section("Draw") {
                ColorPicker("Color", selection: $inkColor)
                LineWidthInputRow(
                    title: "Line Width",
                    value: $inkLineWidth,
                    step: lineWidthStep,
                    max: lineWidthMax,
                    allowsZero: false
                )
            }
        }
        .frame(minWidth: 320, maxHeight: 260)
    }
}

// MARK: - Text Tool Options

struct TextToolOptionsView: View {
    @Binding var textColor: Color
    @Binding var backgroundColor: Color
    @Binding var fontSize: CGFloat
    @Binding var isBold: Bool
    @Binding var textAlignment: NSTextAlignment
    @Binding var verticalAlignment: TextVerticalAlignment
    @Binding var borderWidth: CGFloat
    @Binding var borderColor: Color
    var lineWidthStep: CGFloat
    var lineWidthMax: CGFloat

    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var maxHeight: CGFloat {
        verticalSizeClass == .compact ? 360 : 560
    }

    var body: some View {
        Form {
            Section("Text") {
                ColorPicker("Text Color", selection: $textColor)
                LineWidthInputRow(
                    title: "Font Size",
                    value: $fontSize,
                    step: 1,
                    max: 144,
                    allowsZero: false,
                    fieldLabel: "Font size"
                )
                Toggle("Bold", isOn: $isBold)
                Picker("Horizontal Alignment", selection: $textAlignment) {
                    Label("Leading", systemImage: "text.alignleft")
                        .tag(NSTextAlignment.left)
                    Label("Center", systemImage: "text.aligncenter")
                        .tag(NSTextAlignment.center)
                    Label("Trailing", systemImage: "text.alignright")
                        .tag(NSTextAlignment.right)
                }
                Picker("Vertical Alignment", selection: $verticalAlignment) {
                    Label("Top", systemImage: "arrow.up.to.line")
                        .tag(TextVerticalAlignment.top)
                    Label("Middle", systemImage: "arrow.up.and.down")
                        .tag(TextVerticalAlignment.middle)
                    Label("Bottom", systemImage: "arrow.down.to.line")
                        .tag(TextVerticalAlignment.bottom)
                }
            }

            Section("Text Box") {
                ColorPicker("Background", selection: $backgroundColor, supportsOpacity: true)
                ColorPicker("Border Color", selection: $borderColor)
                LineWidthInputRow(
                    title: "Border Width",
                    value: $borderWidth,
                    step: lineWidthStep,
                    max: lineWidthMax,
                    allowsZero: true
                )
            }
        }
        .frame(minWidth: 340, maxHeight: maxHeight)
    }
}

// MARK: - Shape Tool Options

struct ShapeToolOptionsView: View {
    @Binding var shapeKind: OverlayShapeKind
    @Binding var strokeColor: Color
    @Binding var lineWidth: CGFloat
    var lineWidthStep: CGFloat
    var lineWidthMax: CGFloat

    var body: some View {
        Form {
            Section("Shape") {
                Picker("Shape", selection: $shapeKind) {
                    ForEach(Self.shapeKinds, id: \.self) { kind in
                        Label(label(for: kind), systemImage: iconName(for: kind))
                            .tag(kind)
                    }
                }
                ColorPicker("Stroke Color", selection: $strokeColor)
                LineWidthInputRow(
                    title: "Line Width",
                    value: $lineWidth,
                    step: lineWidthStep,
                    max: lineWidthMax,
                    allowsZero: false
                )
            }
        }
        .frame(minWidth: 320, maxHeight: 360)
    }

    private static let shapeKinds: [OverlayShapeKind] = [
        .circle,
        .rectangle,
        .triangle,
        .line,
        .arrow,
        .doubleArrow,
    ]

    private func iconName(for kind: OverlayShapeKind) -> String {
        switch kind {
        case .circle: return "circle"
        case .rectangle: return "rectangle"
        case .triangle: return "triangle"
        case .line: return "line.diagonal"
        case .arrow: return "arrow.up.right"
        case .doubleArrow: return "arrow.left.and.right"
        }
    }

    private func label(for kind: OverlayShapeKind) -> String {
        switch kind {
        case .circle: return "Circle"
        case .rectangle: return "Rectangle"
        case .triangle: return "Triangle"
        case .line: return "Line"
        case .arrow: return "Arrow"
        case .doubleArrow: return "Double Arrow"
        }
    }
}

// MARK: - Image Border Defaults

struct ImageBorderToolOptionsView: View {
    @Binding var borderWidth: CGFloat
    @Binding var borderColor: Color
    var lineWidthStep: CGFloat
    var lineWidthMax: CGFloat

    var body: some View {
        Form {
            Section("Image Border") {
                ColorPicker("Border Color", selection: $borderColor)
                LineWidthInputRow(
                    title: "Default Width",
                    value: $borderWidth,
                    step: lineWidthStep,
                    max: lineWidthMax,
                    allowsZero: true
                )
            }
        }
        .frame(minWidth: 320, maxHeight: 240)
    }
}

// MARK: - Eraser Tool Options

struct EraserToolOptionsView: View {
    @Binding var eraserRadius: CGFloat

    var body: some View {
        Form {
            Section("Eraser") {
                LineWidthInputRow(
                    title: "Size",
                    value: $eraserRadius,
                    step: 1,
                    max: 48,
                    allowsZero: false
                )
            }
        }
        .frame(minWidth: 320, maxHeight: 180)
    }
}

// MARK: - Line width

private struct LineWidthStepperControl: View {
    @Binding var value: CGFloat
    let step: CGFloat
    let max: CGFloat
    let allowsZero: Bool
    var fieldLabel: String = "Width"

    private var minValue: CGFloat { allowsZero ? 0 : Swift.max(step, 0.25) }

    var body: some View {
        VStack(alignment: .leading) {
            Stepper(
                value: Binding(
                    get: { Double(value) },
                    set: { newValue in
                        value = LineWidthFormatting.snap(
                            CGFloat(newValue),
                            step: step,
                            min: minValue,
                            max: max
                        )
                    }
                ),
                in: Double(minValue)...Double(max),
                step: Double(step)
            ) {
                Text("\(fieldLabel): \(formattedNumber(for: value)) pt")
            }

            if allowsZero {
                Button("None") {
                    value = 0
                }
            }
        }
    }

    private func formattedNumber(for value: CGFloat) -> String {
        if allowsZero && value <= 0 { return "0" }
        if step < 1 {
            return String(format: "%.1f", Double(value))
        }
        return "\(Int(value.rounded()))"
    }
}

struct LineWidthInputRow: View {
    var title: String?
    @Binding var value: CGFloat
    let step: CGFloat
    let max: CGFloat
    let allowsZero: Bool
    var fieldLabel: String = "Width"

    var body: some View {
        LineWidthStepperControl(
            value: $value,
            step: step,
            max: max,
            allowsZero: allowsZero,
            fieldLabel: title ?? fieldLabel
        )
    }
}

struct ToolbarLineWidthStepperPanel: View {
    @Binding var width: CGFloat
    let step: CGFloat
    let max: CGFloat
    let allowsZero: Bool
    var title: String = "Width"

    var body: some View {
        Form {
            Section(title) {
                LineWidthStepperControl(value: $width, step: step, max: max, allowsZero: allowsZero)
            }
        }
        .frame(minWidth: 320, maxHeight: 180)
    }
}

struct ToolbarFontSizeStepperPanel: View {
    @Binding var fontSize: CGFloat
    var title: String = "Font Size"

    var body: some View {
        Form {
            Section(title) {
                LineWidthStepperControl(
                    value: $fontSize,
                    step: 1,
                    max: 144,
                    allowsZero: false,
                    fieldLabel: "Font Size"
                )
            }
        }
        .frame(minWidth: 320, maxHeight: 180)
    }
}

struct ToolbarBorderWidthColorPanel: View {
    @Binding var width: CGFloat
    @Binding var color: Color
    let step: CGFloat
    let max: CGFloat
    var title: String = "Border"

    var body: some View {
        Form {
            Section(title) {
                ColorPicker("Color", selection: $color)
                LineWidthStepperControl(value: $width, step: step, max: max, allowsZero: true)
            }
        }
        .frame(minWidth: 320, maxHeight: 240)
    }
}
