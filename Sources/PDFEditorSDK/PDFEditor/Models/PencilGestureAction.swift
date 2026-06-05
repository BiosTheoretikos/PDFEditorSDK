enum PencilGestureAction: String, Codable, CaseIterable, Identifiable {
    case noAction = "no_action"
    case switchToLastTool = "switch_to_last_tool"
    case undo = "undo"
    case redo = "redo"
    case toggleEraser = "toggle_eraser"
    case activateSelect = "activate_select"
    case activateDraw = "activate_draw"
    case activateEraser = "activate_eraser"
    case activateText = "activate_text"
    case activateShape = "activate_shape"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .noAction: return "None"
        case .switchToLastTool: return "Switch to Last Tool"
        case .undo: return "Undo"
        case .redo: return "Redo"
        case .toggleEraser: return "Toggle Eraser"
        case .activateSelect: return "Select Tool"
        case .activateDraw: return "Draw Tool"
        case .activateEraser: return "Eraser Tool"
        case .activateText: return "Text Tool"
        case .activateShape: return "Shape Tool"
        }
    }

    var systemImage: String {
        switch self {
        case .noAction: return "minus"
        case .switchToLastTool: return "arrow.triangle.2.circlepath"
        case .undo: return "arrow.uturn.backward"
        case .redo: return "arrow.uturn.forward"
        case .toggleEraser: return "eraser"
        case .activateSelect: return "arrow.up.left.and.down.right.magnifyingglass"
        case .activateDraw: return "pencil"
        case .activateEraser: return "eraser.fill"
        case .activateText: return "textformat"
        case .activateShape: return "square.on.circle"
        }
    }

    var isExclusive: Bool { self != .noAction }
}
