//
//  DrawingPDFView+PencilInteraction.swift
//  PDFEditorSDK
//

import UIKit

// MARK: - UIPencilInteractionDelegate

extension DrawingPDFView: UIPencilInteractionDelegate {

    // MARK: Double Tap

    /// Legacy tap handler — covers iOS < 17.5. Apple Pencil 2 and Pro only.
    /// On iOS 17.5+ the system calls `pencilInteraction(_:didReceiveTap:)` instead.
    func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
        guard let vm = formViewModel else { return }
        vm.perform(vm.pencilInput.doubleTapAction)
    }

    /// iOS 17.5+ tap handler — supersedes `pencilInteractionDidTap` on iOS 17.5+.
    /// Handles double-tap on Apple Pencil 2 and Apple Pencil Pro.
    @available(iOS 17.5, *)
    func pencilInteraction(_ interaction: UIPencilInteraction,
                           didReceiveTap tap: UIPencilInteraction.Tap) {
        guard let vm = formViewModel else { return }
        vm.perform(vm.pencilInput.doubleTapAction)
    }

    // MARK: Squeeze (Apple Pencil Pro, iOS 17.5+)

    /// Detects single and double squeezes.
    /// - A single squeeze fires after a short delay (to confirm no second squeeze).
    /// - A second squeeze arriving within that delay cancels the single and fires double.
    @available(iOS 17.5, *)
    func pencilInteraction(_ interaction: UIPencilInteraction,
                           didReceiveSqueeze squeeze: UIPencilInteraction.Squeeze) {
        guard squeeze.phase == .ended, let vm = formViewModel else { return }

        if singleSqueezePendingTask != nil {
            // A second squeeze arrived while we were waiting → double squeeze
            singleSqueezePendingTask?.cancel()
            singleSqueezePendingTask = nil
            vm.perform(vm.pencilInput.doubleSqueezeAction)
        } else {
            // First squeeze: wait briefly to confirm no second one follows
            singleSqueezePendingTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(400))
                guard let self, !Task.isCancelled else { return }
                self.singleSqueezePendingTask = nil
                vm.perform(vm.pencilInput.squeezeAction)
            }
        }
    }
}
