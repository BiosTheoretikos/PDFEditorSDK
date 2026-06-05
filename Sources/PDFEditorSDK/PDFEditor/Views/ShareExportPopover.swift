import SwiftUI

enum ShareExportMode {
    case flattened
    case original
}

struct ShareExportPopover: View {
    let onSelect: (ShareExportMode) -> Void

    var body: some View {
        Form {
            Section("Export As") {
                Button {
                    onSelect(.flattened)
                } label: {
                    Label("Flattened Copy", systemImage: "doc.plaintext")
                }

                Button {
                    onSelect(.original)
                } label: {
                    Label("Original (Editable)", systemImage: "pencil.and.outline")
                }
            }
        }
        .frame(minWidth: 320, maxHeight: 180)
        .presentationCompactAdaptation(.popover)
    }
}
