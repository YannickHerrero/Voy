import SwiftUI

struct PhotoNormalizationPreview: View {
    @Environment(\.dismiss) private var dismiss

    let result: PhotoProcessingResult
    let onUse: (PreparedImage) -> Void
    @State private var usesCutout: Bool

    init(result: PhotoProcessingResult, onUse: @escaping (PreparedImage) -> Void) {
        self.result = result
        self.onUse = onUse
        _usesCutout = State(initialValue: result.normalized != nil)
    }

    private var selectedImage: PreparedImage {
        if usesCutout, let normalized = result.normalized {
            return normalized
        }
        return result.original
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                StoredImageView(data: selectedImage.displayData, symbol: "photo")
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                if result.normalized != nil {
                    Picker("Photo Style", selection: $usesCutout) {
                        Text("Cutout").tag(true)
                        Text("Original").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Choose cutout or original photo")

                    Text(usesCutout
                         ? "The object is centered with a consistent margin."
                         : "The original background will be kept.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Label(
                        "The background could not be removed cleanly. You can still use the original photo.",
                        systemImage: "info.circle"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: 620)
            .padding()
            .frame(maxWidth: .infinity)
            .navigationTitle("Photo Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use Photo") {
                        onUse(selectedImage)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
