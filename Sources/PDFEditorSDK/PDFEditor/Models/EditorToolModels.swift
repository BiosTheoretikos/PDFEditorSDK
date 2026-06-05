enum EditorTool {
    case select
    case form
    case draw
    case erase
    case text
    case shape
    case pencilKit
}

enum OverlayShapeKind: String, Codable {
    case circle
    case rectangle
    case triangle
    case line
    case arrow
    case doubleArrow
}

enum TextVerticalAlignment: String, Codable {
    case top
    case middle
    case bottom
}

enum SelectedOverlayKind {
    case textBox, image, shape
}
