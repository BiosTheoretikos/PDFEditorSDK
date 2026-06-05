import SwiftUI

enum ShareExportMode {
    case flattened
    case original
}

struct ShareExportPopover: View {
    let onSelect: (ShareExportMode) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Export As")
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            Divider()

            Button {
                onSelect(.flattened)
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Label("Flattened Copy", systemImage: "doc.plaintext")
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    Text("Annotations and edits are permanently baked in. Best for sharing a final copy.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider()

            Button {
                onSelect(.original)
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Label("Original (Editable)", systemImage: "pencil.and.outline")
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    Text("Keeps the document fully editable. Recipients can open and continue editing in a compatible PDF editor.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider()
        }
        .frame(width: 300)
        .presentationCompactAdaptation(.popover)
    }
}
