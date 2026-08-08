import Foundation
import UIKit

enum WebImageDownloader {
    enum DownloadError: LocalizedError {
        case invalidResponse
        case fileTooLarge
        case notAnImage

        var errorDescription: String? {
            switch self {
            case .invalidResponse: "The website did not return that image."
            case .fileTooLarge: "That image is too large to import."
            case .notAnImage: "The selected file is not a supported image."
            }
        }
    }

    static func download(_ url: URL, from pageURL: URL?) async throws -> Data {
        var request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 30)
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        if let pageURL {
            request.setValue(pageURL.absoluteString, forHTTPHeaderField: "Referer")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse, (200...299).contains(response.statusCode) else {
            throw DownloadError.invalidResponse
        }
        guard data.count <= 30_000_000 else {
            throw DownloadError.fileTooLarge
        }
        guard UIImage(data: data) != nil else {
            throw DownloadError.notAnImage
        }
        return data
    }
}
