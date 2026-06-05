import UIKit

struct OverlayDocumentMetadata: Codable {
    var textBoxes: [OverlayTextBoxMeta]
    var images: [OverlayImageMeta]
    var shapes: [OverlayShapeMeta]

    init(textBoxes: [OverlayTextBoxMeta] = [], images: [OverlayImageMeta] = [], shapes: [OverlayShapeMeta] = []) {
        self.textBoxes = textBoxes
        self.images = images
        self.shapes = shapes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        textBoxes = try container.decodeIfPresent([OverlayTextBoxMeta].self, forKey: .textBoxes) ?? []
        images = try container.decodeIfPresent([OverlayImageMeta].self, forKey: .images) ?? []
        shapes = try container.decodeIfPresent([OverlayShapeMeta].self, forKey: .shapes) ?? []
    }
}

struct OverlayTextBoxMeta: Codable {
    var id: UUID
    var pageIndex: Int
    var rect: RectCodable
    var text: String
    var background: RGBAColor
    var fontSize: CGFloat?
    var isBold: Bool?
    var textColor: RGBAColor?
    var textAlignment: Int?
    var verticalAlignment: String?
    var autoResize: Bool?
    var borderWidth: CGFloat?
    var borderColor: RGBAColor?
}

struct OverlayImageMeta: Codable {
    var id: UUID
    var pageIndex: Int
    var rect: RectCodable
    var imageBase64: String
    var borderWidth: CGFloat?
    var borderColor: RGBAColor?
}

struct OverlayShapeMeta: Codable {
    var id: UUID
    var pageIndex: Int
    var rect: RectCodable
    var kindRaw: String
    var strokeColor: RGBAColor
    var lineWidth: CGFloat
    var lineFlippedH: Bool?
    var lineFlippedV: Bool?
}

struct RectCodable: Codable {
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat

    init(_ rect: CGRect) {
        x = rect.origin.x
        y = rect.origin.y
        width = rect.size.width
        height = rect.size.height
    }

    var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}

struct RGBAColor: Codable {
    var r: CGFloat
    var g: CGFloat
    var b: CGFloat
    var a: CGFloat

    init(_ color: UIColor) {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    init(r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    var uiColor: UIColor {
        UIColor(red: r, green: g, blue: b, alpha: a)
    }
}
