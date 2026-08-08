import SwiftUI
import UIKit

struct StoredImageView: View {
    let data: Data?
    var symbol = "photo"

    @State private var image: UIImage?

    private var cacheKey: String? {
        guard let data else { return nil }
        return "\(data.count)-\(data.prefix(64).hashValue)-\(data.suffix(16).hashValue)"
    }

    var body: some View {
        ZStack {
            Color(uiColor: .secondarySystemBackground)

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: symbol)
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .task(id: cacheKey) {
            guard let data, let cacheKey else {
                image = nil
                return
            }
            image = await StoredImageCache.shared.image(for: data, key: cacheKey)
        }
    }
}

private actor StoredImageCache {
    static let shared = StoredImageCache()

    private let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 300
        cache.totalCostLimit = 100 * 1_024 * 1_024
        return cache
    }()

    func image(for data: Data, key: String) -> UIImage? {
        if let cached = cache.object(forKey: key as NSString) {
            return cached
        }
        guard let decoded = UIImage(data: data) else { return nil }
        let image = decoded.preparingForDisplay() ?? decoded
        let estimatedCost = (image.cgImage?.bytesPerRow ?? 0) * (image.cgImage?.height ?? 0)
        cache.setObject(image, forKey: key as NSString, cost: estimatedCost)
        return image
    }
}
