import SwiftUI
import PDFKit

struct PDFThumbnailStrip: View {
    @Bindable var viewModel: PDFFormViewModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                LazyHStack {
                    ForEach(0..<viewModel.pageCount, id: \.self) { index in
                        Button {
                            viewModel.goToPage(index: index)
                        } label: {
                            VStack {
                                thumbnailView(for: index)
                                Label(
                                    "Page \(index + 1)",
                                    systemImage: index == viewModel.currentPageIndex ? "checkmark.circle.fill" : "doc"
                                )
                            }
                        }
                        .id(index)
                    }
                }
            }
            .frame(height: 128)
            .onAppear {
                proxy.scrollTo(viewModel.currentPageIndex, anchor: .center)
            }
            .onChange(of: viewModel.currentPageIndex) { _, newValue in
                withAnimation {
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
        } else {
            Image(systemName: "doc")
                .frame(width: 66, height: 86)
        }
    }
}
