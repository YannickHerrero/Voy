import SwiftUI

struct InventoryItemDetailView: View {
    let item: InventoryItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                StoredImageView(data: item.imageData ?? item.thumbnailData, symbol: "shippingbox")
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                VStack(alignment: .leading, spacing: 10) {
                    Text(item.name)
                        .font(.title2.weight(.semibold))

                    Label(item.status.title, systemImage: item.status.symbol)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let description = item.itemDescription, !description.isEmpty {
                        Text(description)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                }
            }
            .frame(maxWidth: 700, alignment: .leading)
            .padding()
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
