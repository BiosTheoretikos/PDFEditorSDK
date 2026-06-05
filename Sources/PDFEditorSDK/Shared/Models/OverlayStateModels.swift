import UIKit

struct OverlayTextBoxState: Identifiable {
    let id: UUID
    var frame: CGRect
    var text: String
    var backgroundColor: UIColor
    var fontSize: CGFloat
    var isBold: Bool
    var textColor: UIColor
    var textAlignment: NSTextAlignment = .left
    var verticalAlignment: TextVerticalAlignment = .top
    var borderWidth: CGFloat = 0
    var borderColor: UIColor = .black
}

struct OverlayImageState: Identifiable {
    let id: UUID
    var frame: CGRect
    var imageData: Data
    var borderWidth: CGFloat = 0
    var borderColor: UIColor = .black
}

struct OverlayShapeState: Identifiable {
    let id: UUID
    var frame: CGRect
    var kind: OverlayShapeKind
    var strokeColor: UIColor
    var lineWidth: CGFloat
    var lineFlippedH: Bool = false
    var lineFlippedV: Bool = false
}
