enum ImageUndoAction {
    case stroke(add: InkStroke?, remove: InkStroke?)
    case eraseSession(old: [InkStroke], new: [InkStroke])
    case textBox(add: OverlayTextBoxState?, remove: OverlayTextBoxState?)
    case textBoxUpdate(before: OverlayTextBoxState, after: OverlayTextBoxState)
    case imageBox(add: OverlayImageState?, remove: OverlayImageState?)
    case imageBoxUpdate(before: OverlayImageState, after: OverlayImageState)
    case imageShape(add: OverlayShapeState?, remove: OverlayShapeState?)
    case imageShapeUpdate(before: OverlayShapeState, after: OverlayShapeState)
}
