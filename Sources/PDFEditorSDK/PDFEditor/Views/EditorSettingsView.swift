//
//  EditorSettingsView.swift
//  PDFEditorSDK
//

import SwiftUI

// MARK: - Editor Settings View

struct EditorSettingsView: View {
    @Binding var drawWithFinger: Bool
    @Binding var pencilOnlyAnnotations: Bool
    @Binding var pencilDoubleTapAction: PencilGestureAction
    @Binding var pencilSqueezeAction: PencilGestureAction
    @Binding var pencilDoubleSqueezeAction: PencilGestureAction

    var body: some View {
        Form {
            Section("Input Mode") {
                Toggle(isOn: $pencilOnlyAnnotations) {
                    Label("Pencil Only", systemImage: "pencil.tip")
                }
                .onChange(of: pencilOnlyAnnotations) { _, newValue in
                    if newValue { drawWithFinger = false }
                }

                Toggle(isOn: $drawWithFinger) {
                    Label("Draw with Finger", systemImage: "hand.draw")
                }
                .onChange(of: drawWithFinger) { _, newValue in
                    if newValue { pencilOnlyAnnotations = false }
                }
                .disabled(pencilOnlyAnnotations)
            }

            Section("Pencil Gestures") {
                GesturePickerRow(
                    label: "Double Tap",
                    icon: "hand.tap",
                    selection: $pencilDoubleTapAction,
                    otherSelections: [pencilSqueezeAction, pencilDoubleSqueezeAction]
                )
                .onChange(of: pencilDoubleTapAction) { _, newValue in
                    clearConflictsForDoubleTap(newValue)
                }

                GesturePickerRow(
                    label: "Single Squeeze",
                    icon: "hand.point.up.left",
                    selection: $pencilSqueezeAction,
                    otherSelections: [pencilDoubleTapAction, pencilDoubleSqueezeAction]
                )
                .onChange(of: pencilSqueezeAction) { _, newValue in
                    clearConflictsForSqueeze(newValue)
                }

                GesturePickerRow(
                    label: "Double Squeeze",
                    icon: "hand.point.up.left.fill",
                    selection: $pencilDoubleSqueezeAction,
                    otherSelections: [pencilDoubleTapAction, pencilSqueezeAction]
                )
                .onChange(of: pencilDoubleSqueezeAction) { _, newValue in
                    clearConflictsForDoubleSqueeze(newValue)
                }
            }
        }
        .frame(minWidth: 340, maxHeight: 420)
    }

    private func clearConflictsForDoubleTap(_ newValue: PencilGestureAction) {
        guard newValue.isExclusive else { return }
        if pencilSqueezeAction == newValue { pencilSqueezeAction = .noAction }
        if pencilDoubleSqueezeAction == newValue { pencilDoubleSqueezeAction = .noAction }
    }

    private func clearConflictsForSqueeze(_ newValue: PencilGestureAction) {
        guard newValue.isExclusive else { return }
        if pencilDoubleTapAction == newValue { pencilDoubleTapAction = .noAction }
        if pencilDoubleSqueezeAction == newValue { pencilDoubleSqueezeAction = .noAction }
    }

    private func clearConflictsForDoubleSqueeze(_ newValue: PencilGestureAction) {
        guard newValue.isExclusive else { return }
        if pencilDoubleTapAction == newValue { pencilDoubleTapAction = .noAction }
        if pencilSqueezeAction == newValue { pencilSqueezeAction = .noAction }
    }
}

// MARK: - Gesture Picker Row

private struct GesturePickerRow: View {
    let label: String
    let icon: String
    @Binding var selection: PencilGestureAction
    let otherSelections: [PencilGestureAction]

    var body: some View {
        Picker(selection: $selection) {
            ForEach(PencilGestureAction.allCases) { action in
                let takenByOther = action.isExclusive && otherSelections.contains(action)
                Label(
                    takenByOther ? "\(action.displayName) (in use)" : action.displayName,
                    systemImage: action.systemImage
                )
                .tag(action)
            }
        } label: {
            Label(label, systemImage: icon)
        }
    }
}
