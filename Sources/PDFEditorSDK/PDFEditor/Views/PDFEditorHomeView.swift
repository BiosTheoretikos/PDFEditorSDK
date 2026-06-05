import SwiftUI

struct PDFEditorHomeView: View {
    @State private var path: [EditorRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            PDFBrowseView(
                onOpen: { url in path.append(.editor(url)) }
            )
            .navigationDestination(for: EditorRoute.self) { route in
                switch route {
                case .editor(let url):
                    PDFEditorHomeContainer(
                        url: url,
                        showsDismissButton: true,
                        onSaveNavigate: { path.removeAll() }
                    )
                }
            }
        }
    }
}

enum EditorRoute: Hashable {
    case editor(URL)
}

private struct PDFEditorHomeContainer: View {
    @State private var viewModel: PDFFormViewModel
    let showsDismissButton: Bool
    let onSaveNavigate: (() -> Void)?

    init(url: URL, showsDismissButton: Bool = false, onSaveNavigate: (() -> Void)? = nil) {
        _viewModel = State(initialValue: PDFFormViewModel(documentURL: url))
        self.showsDismissButton = showsDismissButton
        self.onSaveNavigate = onSaveNavigate
    }

    var body: some View {
        PDFFormEditorView(
            viewModel: viewModel,
            showsDismissButton: showsDismissButton,
            onSaveNavigate: onSaveNavigate
        )
    }
}

#Preview {
    PDFEditorHomeView()
}
