import SwiftUI
import UniformTypeIdentifiers

struct PDFBrowseView: View {
    @State private var files: [URL] = []
    var onOpen: ((URL) -> Void)?
    @State private var openError: String?
    @State private var isShowingOpenAlert = false
    @State private var isShowingFileImporter = false

    var body: some View {
        List {
            Section("Create") {
                Button {
                    if let url = templateURL() {
                        onOpen?(url)
                    } else {
                        openError = "Could not find template PDF."
                        isShowingOpenAlert = true
                    }
                } label: {
                    Label("New From Template", systemImage: "doc.badge.plus")
                }

                Button {
                    isShowingFileImporter = true
                } label: {
                    Label("Open From Files", systemImage: "folder")
                }
            }

            if files.isEmpty {
                ContentUnavailableView(
                    "No Saved PDFs",
                    systemImage: "doc",
                    description: Text("Save a PDF to see it here.")
                )
            } else {
                Section("Saved") {
                    ForEach(files, id: \.self) { url in
                        Button {
                            onOpen?(url)
                        } label: {
                            HStack {
                                Image(systemName: "doc.richtext")
                                    .foregroundStyle(.secondary)
                                Text(url.lastPathComponent)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Browse Documents")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadFiles)
        .fileImporter(
            isPresented: $isShowingFileImporter,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                openImportedFile(url)
            case .failure:
                openError = "Failed to open file from Files."
                isShowingOpenAlert = true
            }
        }
        .alert("Open PDF", isPresented: $isShowingOpenAlert, actions: {
            Button("OK", role: .cancel) { }
        }, message: {
            Text(openError ?? "Failed to open PDF")
        })
    }

    private func templateURL() -> URL? {
        if let url = Bundle.main.url(forResource: "SampleForm", withExtension: "pdf") {
            return url
        }
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = documentsPath.appendingPathComponent("SampleForm.pdf")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private func loadFiles() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folderURL = documentsPath.appendingPathComponent("PDFEdits", isDirectory: true)
        let files = (try? FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        self.files = files.sorted { lhs, rhs in
            let leftDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rightDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return leftDate > rightDate
        }
    }

    private func openImportedFile(_ url: URL) {
        let didStart = url.startAccessingSecurityScopedResource()
        defer {
            if didStart { url.stopAccessingSecurityScopedResource() }
        }

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folderURL = documentsPath.appendingPathComponent("PDFEdits", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            let destinationURL = uniqueDestinationURL(for: url, in: folderURL)
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: url, to: destinationURL)
            loadFiles()
            onOpen?(destinationURL)
        } catch {
            openError = "Failed to import PDF from Files."
            isShowingOpenAlert = true
        }
    }

    private func uniqueDestinationURL(for sourceURL: URL, in folderURL: URL) -> URL {
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let ext = sourceURL.pathExtension.isEmpty ? "pdf" : sourceURL.pathExtension
        var candidate = folderURL.appendingPathComponent("\(baseName).\(ext)")
        var counter = 1
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folderURL.appendingPathComponent("\(baseName)-\(counter).\(ext)")
            counter += 1
        }
        return candidate
    }
}
