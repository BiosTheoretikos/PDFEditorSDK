import Foundation
import Testing
import UIKit
@testable import PDFEditor

struct PDFSettingsTests {
    @Test func textSettingsClampInvalidFontSizesBeforePersisting() {
        var preferences = EditorPreferences()
        preferences.textBoxFontSize = -12
        var settings = TextAnnotationSettings(preferences: preferences)

        #expect(settings.fontSize == 1)

        settings.fontSize = 0
        settings.normalize()
        settings.apply(to: &preferences)

        #expect(settings.fontSize == 1)
        #expect(preferences.textBoxFontSize == 1)
    }

    @Test func pencilInputSettingsDisableFingerDrawingForPencilOnlyAnnotations() {
        var preferences = EditorPreferences()
        preferences.drawWithFinger = true
        preferences.pencilOnlyAnnotations = true
        var settings = PencilInputSettings(preferences: preferences)

        settings.normalize()
        settings.apply(to: &preferences)

        #expect(settings.drawWithFinger == false)
        #expect(preferences.drawWithFinger == false)
        #expect(preferences.pencilOnlyAnnotations == true)
    }

    @Test func lineWidthControlSettingsSnapToSupportedValues() {
        var preferences = EditorPreferences()
        preferences.lineWidthStep = 0.76
        preferences.lineWidthMax = 40

        let settings = LineWidthControlSettings(preferences: preferences)

        #expect(settings.step == 1)
        #expect(settings.max == 36)
    }

    @Test func lineWidthFormattingSnapsAndClampsValues() {
        #expect(LineWidthFormatting.snap(5.2, step: 0.5, min: 1, max: 8) == 5)
        #expect(LineWidthFormatting.snap(0.2, step: 0.5, min: 1, max: 8) == 1)
        #expect(LineWidthFormatting.snap(9.7, step: 0.5, min: 1, max: 8) == 8)
        #expect(LineWidthFormatting.snap(6.2, step: 0, min: 1, max: 8) == 6.2)
    }

    @Test func colorCodableRoundTripsUIKitColorComponents() {
        let color = RGBAColor(UIColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 0.8))

        #expect(abs(color.r - 0.2) < 0.001)
        #expect(abs(color.g - 0.4) < 0.001)
        #expect(abs(color.b - 0.6) < 0.001)
        #expect(abs(color.a - 0.8) < 0.001)
    }

    @Test func preferencesSaveLoadRoundTripsAndNormalizesPersistedValues() {
        PDFEditorTestSupport.withPreservedEditorPreferences {
            var preferences = EditorPreferences()
            preferences.inkLineWidth = 7
            preferences.activeShapeKind = .triangle
            preferences.pencilDoubleTapAction = .activateText
            preferences.lineWidthStep = 0.76
            preferences.lineWidthMax = 47

            preferences.save()
            let loaded = EditorPreferences.load()

            #expect(loaded.inkLineWidth == 7)
            #expect(loaded.activeShapeKind == .triangle)
            #expect(loaded.pencilDoubleTapAction == .activateText)
            #expect(loaded.lineWidthStep == 1)
            #expect(loaded.lineWidthMax == 48)
        }
    }

    @Test func legacyPDFScopedPreferencesMigrateToSharedPreferences() throws {
        try PDFEditorTestSupport.withPreservedEditorPreferences {
            var legacyPreferences = EditorPreferences()
            legacyPreferences.shapeLineWidth = 9
            legacyPreferences.activeShapeKind = .circle
            let data = try JSONEncoder().encode(legacyPreferences)
            UserDefaults.standard.set(data, forKey: "com.pdfeditor.editorPreferences.pdf")

            let loaded = EditorPreferences.load()

            #expect(loaded.shapeLineWidth == 9)
            #expect(loaded.activeShapeKind == .circle)
            #expect(UserDefaults.standard.data(forKey: "com.pdfeditor.editorPreferences") != nil)
            #expect(UserDefaults.standard.bool(forKey: "com.pdfeditor.editorPreferences.pdfOnlyMigrated"))
        }
    }

    @Test func settingsApplyBackToPreferences() {
        var preferences = EditorPreferences()

        var drawing = DrawingAnnotationSettings(preferences: preferences)
        drawing.inkColor = .systemRed
        drawing.lineWidth = 5
        drawing.eraserRadius = 14
        drawing.apply(to: &preferences)

        var shape = ShapeAnnotationSettings(preferences: preferences)
        shape.kind = .doubleArrow
        shape.strokeColor = .systemGreen
        shape.lineWidth = 6
        shape.apply(to: &preferences)

        var image = ImageAnnotationSettings(preferences: preferences)
        image.borderWidth = 3
        image.borderColor = .systemPurple
        image.apply(to: &preferences)

        var display = EditorDisplaySettings(preferences: preferences)
        display.isThumbnailOverlayVisible = false
        display.apply(to: &preferences)

        #expect(preferences.inkLineWidth == 5)
        #expect(preferences.eraserRadius == 14)
        #expect(preferences.activeShapeKind == .doubleArrow)
        #expect(preferences.shapeLineWidth == 6)
        #expect(preferences.imageBorderWidth == 3)
        #expect(preferences.isThumbnailOverlayVisible == false)
    }
}
