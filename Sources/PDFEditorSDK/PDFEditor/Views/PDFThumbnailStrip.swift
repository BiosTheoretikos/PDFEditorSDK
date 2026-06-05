import SwiftUI
import PDFKit

struct PDFThumbnailStrip: View {
    @Bindable var viewModel: PDFFormViewModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: true) {
                HStack(spacing: 10) {
                    ForEach(0..<viewModel.pageCount, id: \.self) { index in
                        Button {
                            viewModel.goToPage(index: index)
                        } label: {
                            VStack(spacing: 0) {
                                thumbnailView(for: index)
                                Text("Page \(index + 1)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .padding(.vertical, 4)
                                    .frame(maxWidth: .infinity)
                                    .background(.ultraThinMaterial)
                            }
                            .frame(width: 66)
                            .clipShape(.rect(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(
                                        index == viewModel.currentPageIndex ? Color.accentColor : Color.black.opacity(0.08),
                                        lineWidth: index == viewModel.currentPageIndex ? 2 : 1
                                    )
                            )
                            .shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
                        }
                        .buttonStyle(.plain)
                        .id(index)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .frame(height: 118)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
            .onAppear {
                proxy.scrollTo(viewModel.currentPageIndex, anchor: .center)
            }
            .onChange(of: viewModel.currentPageIndex) { _, newValue in
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }

    @ViewBuilder
    private func thumbnailView(for index: Int) -> some View {
        if let page = viewModel.pdfDocument?.page(at: index) {
            let image = page.thumbnail(of: CGSize(width: 66, height: 86), for: .mediaBox)
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 66, height: 86)
                .background(Color.white)
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.12))
                .frame(width: 66, height: 86)
        }
    }
}
