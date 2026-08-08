import Foundation
import UIKit

struct PreparedImage: Sendable {
    let displayData: Data
    let thumbnailData: Data
    let originalData: Data
}

enum ImageFileProcessor {
    enum ProcessingError: LocalizedError {
        case unreadableImage
        case encodingFailed

        var errorDescription: String? {
            switch self {
            case .unreadableImage: "That image could not be opened."
            case .encodingFailed: "That image could not be prepared for storage."
            }
        }
    }

    static func prepare(_ sourceData: Data) async throws -> PreparedImage {
        try await Task.detached(priority: .userInitiated) {
            guard let source = UIImage(data: sourceData) else {
                throw ProcessingError.unreadableImage
            }

            let original = source.scaledToFit(maximumDimension: 3_000)
            let display = source.scaledToFit(maximumDimension: 1_800)
            let thumbnail = source.scaledToFit(maximumDimension: 480)

            guard
                let originalData = original.jpegData(compressionQuality: 0.9),
                let displayData = display.jpegData(compressionQuality: 0.84),
                let thumbnailData = thumbnail.jpegData(compressionQuality: 0.78)
            else {
                throw ProcessingError.encodingFailed
            }

            return PreparedImage(
                displayData: displayData,
                thumbnailData: thumbnailData,
                originalData: originalData
            )
        }.value
    }
}

private extension UIImage {
    func scaledToFit(maximumDimension: CGFloat) -> UIImage {
        let sourceSize = size
        let longestEdge = max(sourceSize.width, sourceSize.height)
        let scale = min(1, maximumDimension / max(longestEdge, 1))
        let targetSize = CGSize(
            width: max(1, (sourceSize.width * scale).rounded()),
            height: max(1, (sourceSize.height * scale).rounded())
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
