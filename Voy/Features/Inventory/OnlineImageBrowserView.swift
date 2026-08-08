import SwiftUI

struct OnlineImageSelection: Sendable {
    let data: Data
    let pageURL: URL?
    let imageURL: URL
}

struct OnlineImageBrowserView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var browser = WebBrowserModel()
    @State private var candidates: [WebImageCandidate] = []
    @State private var showsCandidates = false
    @State private var isDiscovering = false
    @State private var errorMessage: String?

    let onSelect: (OnlineImageSelection) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                addressBar
                Divider()
                WebBrowserView(model: browser)
            }
            .navigationTitle(browser.pageTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    discoverImages()
                } label: {
                    if isDiscovering {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("Find Images on This Page", systemImage: "photo.stack")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isDiscovering || browser.isLoading)
                .padding()
                .background(.bar)
            }
            .navigationDestination(isPresented: $showsCandidates) {
                OnlineImageCandidateGrid(
                    candidates: candidates,
                    pageURL: browser.webView?.url,
                    onSelect: { selection in
                        onSelect(selection)
                        dismiss()
                    }
                )
            }
            .alert("Images Unavailable", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "Try another page.")
            }
        }
    }

    private var addressBar: some View {
        HStack(spacing: 10) {
            Button("Back", systemImage: "chevron.backward") { browser.goBack() }
                .labelStyle(.iconOnly)
                .disabled(!browser.canGoBack)
            Button("Forward", systemImage: "chevron.forward") { browser.goForward() }
                .labelStyle(.iconOnly)
                .disabled(!browser.canGoForward)

            TextField("Website or search", text: $browser.addressText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .submitLabel(.go)
                .onSubmit { browser.navigate() }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            if browser.isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button("Go") { browser.navigate() }
                    .font(.subheadline.weight(.semibold))
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private func discoverImages() {
        isDiscovering = true
        Task {
            defer { isDiscovering = false }
            do {
                candidates = try await browser.discoverImages()
                if candidates.isEmpty {
                    errorMessage = "No suitable product images were found. Try opening the product’s main page or choosing another site."
                } else {
                    showsCandidates = true
                }
            } catch {
                errorMessage = "This page did not allow its images to be inspected. Try another page or website."
            }
        }
    }
}

private struct OnlineImageCandidateGrid: View {
    let candidates: [WebImageCandidate]
    let pageURL: URL?
    let onSelect: (OnlineImageSelection) -> Void

    @State private var downloadingURL: URL?
    @State private var errorMessage: String?
    private let columns = [GridItem(.adaptive(minimum: 130, maximum: 220), spacing: 14)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 18) {
                ForEach(candidates) { candidate in
                    Button {
                        select(candidate)
                    } label: {
                        VStack(alignment: .leading, spacing: 7) {
                            AsyncImage(url: candidate.url, transaction: Transaction(animation: .default)) { phase in
                                switch phase {
                                case let .success(image):
                                    image
                                        .resizable()
                                        .scaledToFit()
                                case .failure:
                                    ContentUnavailableView("Unavailable", systemImage: "photo.badge.exclamationmark")
                                case .empty:
                                    ProgressView()
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            .aspectRatio(1, contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                            if let resolution = candidate.resolutionDescription {
                                Text(resolution)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .overlay {
                            if downloadingURL == candidate.url {
                                ProgressView()
                                    .padding()
                                    .background(.regularMaterial, in: Circle())
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(downloadingURL != nil)
                    .accessibilityLabel(candidate.description.isEmpty ? "Web image" : candidate.description)
                    .accessibilityHint("Imports this image")
                }
            }
            .padding()
        }
        .navigationTitle("Choose an Image")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Couldn’t Download Image", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Try another image.")
        }
    }

    private func select(_ candidate: WebImageCandidate) {
        downloadingURL = candidate.url
        Task {
            defer { downloadingURL = nil }
            do {
                let data = try await WebImageDownloader.download(candidate.url, from: pageURL)
                onSelect(OnlineImageSelection(data: data, pageURL: pageURL, imageURL: candidate.url))
            } catch {
                errorMessage = "The website blocked or removed that image. Choose another candidate or website."
            }
        }
    }
}
