//
//  PDFEditorView.swift
//  PDFEditorSDK
//
//  Created by Josh Bourke on 5/1/2026.
//

import SwiftUI
import PDFKit
import UIKit

private enum EditorPopover: Identifiable {
    case shareOptions
    case drawOptions
    case eraserOptions
    case textOptions
    case shapeOptions
    case imageBorderOptions
    case selectedImageBorder
    case selectedTextBorder
    case selectedShapeStrokeWidth
    case textFontSize
    case editorSettings

    var id: Self { self }
}

private struct PDFShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct PDFFormEditorView: View {
    @Bindable var viewModel: PDFFormViewModel
    var showsDismissButton = false
    var showsHighlightButton = true
    var showsLockButton = true
    var showsPencilButton = true
    var showsSaveAlert = true
    var onSaveNavigate: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    @State private var isShowingSaveAlert = false
    @State private var isShowingExportAlert = false
    @State private var isShowingImagePicker = false
    @State private var imagePickerSource: ImagePickerSource = .photoLibrary
    @State private var activePopover: EditorPopover?
    @State private var shareItem: PDFShareItem?
    @State private var isShowingInsertPageSheet = false
    @State private var insertPageIndex = 0
    @State private var isShowingRemovePageAlert = false
    @State private var showAddImageSourceDialog = false
    @State private var changesNotSaved = false

    var body: some View {
        coreEditorView
            .fullScreenCover(isPresented: $isShowingImagePicker) {
                ImagePicker(sourceType: imagePickerSource.uiSourceType, allowsEditing: true) { image in
                    viewModel.handleImagePickedFromSheet(image)
                }
            }
            .sheet(isPresented: $isShowingInsertPageSheet) {
                insertPageView
            }
            .sheet(item: $shareItem) { item in
                PDFShareSheet(url: item.url)
            }
            .popover(item: $activePopover, arrowEdge: .bottom) { popover in
                popoverContent(for: popover)
            }
            .onChange(of: viewModel.textSettings.fontSize) { _, _ in viewModel.applyTextStyleToSelectedTextBox() }
            .onChange(of: viewModel.textSettings.isBold) { _, _ in viewModel.applyTextStyleToSelectedTextBox() }
            .onChange(of: viewModel.textSettings.textColor) { _, _ in viewModel.applyTextStyleToSelectedTextBox() }
            .onChange(of: viewModel.textSettings.backgroundColor) { _, _ in viewModel.applyTextStyleToSelectedTextBox() }
            .onChange(of: viewModel.textSettings.textAlignment) { _, _ in viewModel.applyTextStyleToSelectedTextBox() }
            .onChange(of: viewModel.textSettings.verticalAlignment) { _, _ in viewModel.applyTextStyleToSelectedTextBox() }
            .onChange(of: viewModel.shapeSettings.kind) { _, _ in
                guard viewModel.activeTool == .select else { return }
                viewModel.applyShapeStyleToSelected()
            }
            .onChange(of: viewModel.shapeSettings.strokeColor) { _, _ in
                guard viewModel.activeTool == .select else { return }
                viewModel.applyShapeStyleToSelected()
            }
            .onChange(of: viewModel.shapeSettings.lineWidth) { _, _ in
                guard viewModel.activeTool == .select else { return }
                viewModel.applyShapeStyleToSelected()
            }
            .alert("Unsaved Changes", isPresented: $changesNotSaved) {
                Button("Save Changes") {
                    saveAndClose()
                }
                Button("Discard & Close", role: .destructive) {
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("You have unsaved changes. Would you like to save before closing?")
            }
    }

    private var coreEditorView: some View {
        Group {
            if viewModel.pdfDocument != nil {
                SimplePDFView(viewModel: viewModel)
                    .overlay(alignment: .bottom) {
                        if viewModel.displaySettings.isThumbnailOverlayVisible {
                            PDFThumbnailStrip(viewModel: viewModel)
                                .padding()
                        }
                    }
            } else {
                ContentUnavailableView(
                    "No PDF Loaded",
                    systemImage: "doc.fill",
                    description: Text("The PDF form could not be loaded")
                )
            }
        }
        .navigationTitle("PDF Form Editor")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            navigationToolbar
            editingToolbar
        }
        .alert("Save PDF", isPresented: $isShowingSaveAlert, actions: {
            Button("OK", role: .cancel) { }
        }, message: {
            Text(viewModel.saveStatus ?? "No status")
        })
        .alert("Remove Page \(viewModel.currentPageIndex + 1)?", isPresented: $isShowingRemovePageAlert, actions: {
            Button("Remove", role: .destructive) {
                viewModel.removeCurrentPage()
            }
            Button("Cancel", role: .cancel) { }
        }, message: {
            Text("This page will be removed from the document. You can undo this action.")
        })
        .alert("Export PDF", isPresented: $isShowingExportAlert, actions: {
            Button("OK", role: .cancel) { }
        }, message: {
            Text(viewModel.exportStatus ?? "No status")
        })
        .confirmationDialog(
            "Add image to form field",
            isPresented: $viewModel.showFormWidgetImageSourceDialog,
            titleVisibility: .visible
        ) {
            Button("Take Photo") {
                viewModel.beginFormWidgetImagePickFromCamera()
                imagePickerSource = .camera
                isShowingImagePicker = true
            }
            Button("Photo Library") {
                viewModel.beginFormWidgetImagePickFromLibrary()
                imagePickerSource = .photoLibrary
                isShowingImagePicker = true
            }
            Button("Cancel", role: .cancel) {
                viewModel.cancelPendingFormWidgetImagePick()
            }
        } message: {
            Text("Choose a source for this field.")
        }
        .confirmationDialog("Add Image", isPresented: $showAddImageSourceDialog, titleVisibility: .visible) {
            Button("Camera") {
                viewModel.imagePickIsForFormWidget = false
                imagePickerSource = .camera
                isShowingImagePicker = true
            }
            Button("Photo Library") {
                viewModel.imagePickIsForFormWidget = false
                imagePickerSource = .photoLibrary
                isShowingImagePicker = true
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Choose a source for the image.")
        }
    }

    private var insertPageView: some View {
        NavigationStack {
            Form {
                Picker("Insert Position", selection: $insertPageIndex) {
                    ForEach(0...max(viewModel.pageCount, 0), id: \.self) { index in
                        Text(insertPageLabel(for: index))
                            .tag(index)
                    }
                }
                .pickerStyle(.wheel)
            }
            .navigationTitle("Insert Page")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isShowingInsertPageSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Insert") {
                        viewModel.addBlankPage(at: insertPageIndex)
                        isShowingInsertPageSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    @ToolbarContentBuilder
    private var navigationToolbar: some ToolbarContent {
        if showsDismissButton {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close") {
                    viewModel.flushActiveFormFieldChangesIfNeeded()
                    if !viewModel.undoStack.isEmpty {
                        changesNotSaved.toggle()
                    } else {
                        dismiss()
                    }
                }
            }
        }

        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                viewModel.undo()
            } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
            }
            .disabled(!viewModel.canUndo)

            Button {
                viewModel.redo()
            } label: {
                Label("Redo", systemImage: "arrow.uturn.forward")
            }
            .disabled(!viewModel.canRedo)

            Button("Save") {
                saveFromToolbar()
            }

            Button("Share") {
                activePopover = .shareOptions
            }
        }
    }

    @ToolbarContentBuilder
    private var editingToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .bottomBar) {
            toolButton(.select, title: "Select", systemImage: "cursorarrow.rays")
            toolButton(.form, title: "Form", systemImage: "text.document")
            toolButton(.draw, title: "Draw", systemImage: "pencil.and.scribble")
            toolButton(.erase, title: "Erase", systemImage: "eraser")
            toolButton(.text, title: "Text", systemImage: "character.cursor.ibeam")
            toolButton(.shape, title: "Shape", systemImage: iconName(for: viewModel.shapeSettings.kind))

            Button {
                showAddImageSourceDialog = true
            } label: {
                Label("Image", systemImage: "photo.on.rectangle")
            }

            if showsPencilButton {
                toolButton(.pencilKit, title: "Pencil", systemImage: "pencil.and.outline")
            }

            Menu {
                editorMenuItems
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
        }
    }

    private func toolButton(_ tool: EditorTool, title: String, systemImage: String) -> some View {
        Button {
            viewModel.setTool(tool)
        } label: {
            Label(title, systemImage: systemImage)
                .symbolVariant(viewModel.activeTool == tool ? .fill : .none)
        }
    }

    @ViewBuilder
    private func popoverContent(for popover: EditorPopover) -> some View {
        switch popover {
        case .shareOptions:
            ShareExportPopover { mode in
                activePopover = nil
                sharePDF(mode: mode)
            }

        case .drawOptions:
            DrawToolOptionsView(
                inkColor: Binding(
                    get: { Color(viewModel.drawingSettings.inkColor) },
                    set: { viewModel.drawingSettings.inkColor = UIColor($0) }
                ),
                inkLineWidth: $viewModel.drawingSettings.lineWidth,
                lineWidthStep: viewModel.lineWidthControls.step,
                lineWidthMax: viewModel.lineWidthControls.max
            )

        case .eraserOptions:
            EraserToolOptionsView(eraserRadius: $viewModel.drawingSettings.eraserRadius)

        case .textOptions:
            TextToolOptionsView(
                textColor: Binding(
                    get: { Color(viewModel.textSettings.textColor) },
                    set: { viewModel.textSettings.textColor = UIColor($0) }
                ),
                backgroundColor: Binding(
                    get: { Color(viewModel.textSettings.backgroundColor) },
                    set: { viewModel.textSettings.backgroundColor = UIColor($0) }
                ),
                fontSize: $viewModel.textSettings.fontSize,
                isBold: $viewModel.textSettings.isBold,
                textAlignment: $viewModel.textSettings.textAlignment,
                verticalAlignment: $viewModel.textSettings.verticalAlignment,
                borderWidth: $viewModel.textSettings.borderWidth,
                borderColor: Binding(
                    get: { Color(viewModel.textSettings.borderColor) },
                    set: { viewModel.textSettings.borderColor = UIColor($0) }
                ),
                lineWidthStep: viewModel.lineWidthControls.step,
                lineWidthMax: viewModel.lineWidthControls.max
            )

        case .shapeOptions:
            ShapeToolOptionsView(
                shapeKind: $viewModel.shapeSettings.kind,
                strokeColor: Binding(
                    get: { Color(viewModel.shapeSettings.strokeColor) },
                    set: { viewModel.shapeSettings.strokeColor = UIColor($0) }
                ),
                lineWidth: $viewModel.shapeSettings.lineWidth,
                lineWidthStep: viewModel.lineWidthControls.step,
                lineWidthMax: viewModel.lineWidthControls.max
            )

        case .imageBorderOptions:
            ImageBorderToolOptionsView(
                borderWidth: Binding(
                    get: { viewModel.imageSettings.borderWidth },
                    set: { viewModel.commitImageBorderWidth($0) }
                ),
                borderColor: Binding(
                    get: { Color(viewModel.imageSettings.borderColor) },
                    set: { viewModel.commitImageBorderColor(UIColor($0)) }
                ),
                lineWidthStep: viewModel.lineWidthControls.step,
                lineWidthMax: viewModel.lineWidthControls.max
            )

        case .selectedImageBorder:
            ToolbarBorderWidthColorPanel(
                width: Binding(
                    get: { viewModel.imageSettings.borderWidth },
                    set: { viewModel.commitImageBorderWidth($0) }
                ),
                color: Binding(
                    get: { Color(viewModel.imageSettings.borderColor) },
                    set: { viewModel.commitImageBorderColor(UIColor($0)) }
                ),
                step: viewModel.lineWidthControls.step,
                max: viewModel.lineWidthControls.max,
                title: "Image Border"
            )

        case .selectedTextBorder:
            ToolbarBorderWidthColorPanel(
                width: Binding(
                    get: { viewModel.selectedTextBoxBorder.width },
                    set: { viewModel.commitSelectedTextBoxBorderWidth($0) }
                ),
                color: Binding(
                    get: { Color(viewModel.selectedTextBoxBorder.color) },
                    set: { viewModel.commitSelectedTextBoxBorderColor(UIColor($0)) }
                ),
                step: viewModel.lineWidthControls.step,
                max: viewModel.lineWidthControls.max,
                title: "Text Box Border"
            )

        case .selectedShapeStrokeWidth:
            ToolbarLineWidthStepperPanel(
                width: $viewModel.shapeSettings.lineWidth,
                step: viewModel.lineWidthControls.step,
                max: viewModel.lineWidthControls.max,
                allowsZero: false,
                title: "Stroke Width"
            )

        case .textFontSize:
            ToolbarFontSizeStepperPanel(fontSize: $viewModel.textSettings.fontSize)

        case .editorSettings:
            EditorSettingsView(
                drawWithFinger: $viewModel.pencilInput.drawWithFinger,
                pencilOnlyAnnotations: $viewModel.pencilInput.pencilOnlyAnnotations,
                pencilDoubleTapAction: $viewModel.pencilInput.doubleTapAction,
                pencilSqueezeAction: $viewModel.pencilInput.squeezeAction,
                pencilDoubleSqueezeAction: $viewModel.pencilInput.doubleSqueezeAction
            )
        }
    }

    @ViewBuilder
    private var editorMenuItems: some View {
        Section("Tool Options") {
            Button {
                activePopover = .drawOptions
            } label: {
                Label("Draw Settings", systemImage: "paintbrush.pointed")
            }
            Button {
                activePopover = .eraserOptions
            } label: {
                Label("Eraser Settings", systemImage: "circle.dotted")
            }
            Button {
                activePopover = .textOptions
            } label: {
                Label("Text Settings", systemImage: "textformat")
            }
            Button {
                activePopover = .shapeOptions
            } label: {
                Label("Shape Settings", systemImage: "square.on.circle")
            }
            Button {
                activePopover = .imageBorderOptions
            } label: {
                Label("Image Border", systemImage: "square.dashed")
            }
        }

        Section("Document") {
            if showsHighlightButton {
                Button {
                    viewModel.highlightSelectedText()
                } label: {
                    Label("Highlight Selection", systemImage: "highlighter")
                }
                .disabled(!viewModel.hasTextSelection)
            }

            if showsLockButton {
                Button {
                    viewModel.toggleScrollLock()
                } label: {
                    Label(
                        viewModel.pageScrollLocked ? "Unlock Scrolling" : "Lock Scrolling",
                        systemImage: viewModel.pageScrollLocked ? "lock.open" : "lock"
                    )
                }
            }

            Button {
                viewModel.displaySettings.isThumbnailOverlayVisible.toggle()
            } label: {
                Label(
                    viewModel.displaySettings.isThumbnailOverlayVisible ? "Hide Thumbnails" : "Show Thumbnails",
                    systemImage: "rectangle.portrait.on.rectangle.portrait"
                )
            }

            Button {
                insertPageIndex = min(viewModel.currentPageIndex + 1, viewModel.pageCount)
                isShowingInsertPageSheet = true
            } label: {
                Label("Add Page", systemImage: "doc.badge.plus")
            }

            Button(role: .destructive) {
                isShowingRemovePageAlert = true
            } label: {
                Label("Remove Page", systemImage: "doc")
            }
            .disabled(viewModel.pageCount <= 1)
        }

        if viewModel.hasSelectedInkAnnotation || viewModel.hasSelectedOverlayObject {
            Section("Selection") {
                selectionMenuItems
            }
        }

        Section {
            Button {
                activePopover = .editorSettings
            } label: {
                Label("Editor Settings", systemImage: "gearshape")
            }
        }
    }

    @ViewBuilder
    private var selectionMenuItems: some View {
        if viewModel.selectedOverlayKind == .textBox {
            Button {
                activePopover = .textOptions
            } label: {
                Label("Text Settings", systemImage: "textformat")
            }
            Button {
                activePopover = .textFontSize
            } label: {
                Label("Font Size", systemImage: "textformat.size")
            }
            Button {
                activePopover = .selectedTextBorder
            } label: {
                Label("Text Box Border", systemImage: "square.dashed")
            }
        }

        if viewModel.selectedOverlayKind == .shape {
            Button {
                activePopover = .shapeOptions
            } label: {
                Label("Shape Settings", systemImage: iconName(for: viewModel.shapeSettings.kind))
            }
            Button {
                activePopover = .selectedShapeStrokeWidth
            } label: {
                Label("Stroke Width", systemImage: "lineweight")
            }
        }

        if viewModel.selectedOverlayKind == .image {
            Button {
                activePopover = .selectedImageBorder
            } label: {
                Label("Image Border", systemImage: "square.dashed")
            }
        }

        Button(role: .destructive) {
            viewModel.deleteSelectedSelection()
        } label: {
            Label("Delete Selection", systemImage: "trash")
        }
    }

    private func saveAndClose() {
        do {
            try viewModel.savePDF()
            if let onSaveNavigate {
                onSaveNavigate()
            } else {
                dismiss()
            }
        } catch {
            viewModel.saveStatus = error.localizedDescription
            isShowingSaveAlert = true
        }
    }

    private func saveFromToolbar() {
        do {
            try viewModel.savePDF()
            if showsSaveAlert { isShowingSaveAlert = true }
            onSaveNavigate?()
        } catch {
            viewModel.saveStatus = error.localizedDescription
            isShowingSaveAlert = true
        }
    }

    private func sharePDF(mode: ShareExportMode) {
        do {
            let url: URL
            switch mode {
            case .flattened:
                url = try viewModel.exportFlattenedPDF()
            case .original:
                url = try viewModel.exportEditablePDF()
            }
            shareItem = PDFShareItem(url: url)
        } catch {
            viewModel.exportStatus = error.localizedDescription
            isShowingExportAlert = true
        }
    }

    private func insertPageLabel(for index: Int) -> String {
        let pageNumber = index + 1
        if index == 0 {
            return "Before Page 1"
        }
        if index == viewModel.pageCount {
            return "After Page \(viewModel.pageCount)"
        }
        return "Before Page \(pageNumber)"
    }

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
}
