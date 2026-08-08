import Foundation

struct WebImageCandidate: Identifiable, Hashable, Sendable {
    let url: URL
    let width: Int
    let height: Int
    let description: String
    let priority: Int

    var id: URL { url }

    var resolutionDescription: String? {
        guard width > 0, height > 0 else { return nil }
        return "\(width) × \(height)"
    }
}

enum WebImageCandidateProcessor {
    static func filtered(_ candidates: some Sequence<WebImageCandidate>, limit: Int = 80) -> [WebImageCandidate] {
        let obviousAssetTerms = [
            "favicon", "sprite", "logo", "icon", "avatar", "badge", "pixel", "tracker",
            "analytics", "loading", "spinner", "placeholder", "payment", "social"
        ]
        var bestByURL: [URL: WebImageCandidate] = [:]

        for candidate in candidates {
            guard let scheme = candidate.url.scheme?.lowercased(), scheme == "https" || scheme == "http" else {
                continue
            }
            let path = candidate.url.absoluteString.lowercased()
            if candidate.priority < 10_000 && obviousAssetTerms.contains(where: path.contains) {
                continue
            }
            if candidate.width > 0, candidate.height > 0,
               (max(candidate.width, candidate.height) < 300 || min(candidate.width, candidate.height) < 120) {
                continue
            }

            if let existing = bestByURL[candidate.url] {
                if ranking(candidate) > ranking(existing) {
                    bestByURL[candidate.url] = candidate
                }
            } else {
                bestByURL[candidate.url] = candidate
            }
        }

        return bestByURL.values
            .sorted { ranking($0) > ranking($1) }
            .prefix(limit)
            .map { $0 }
    }

    private static func ranking(_ candidate: WebImageCandidate) -> Int64 {
        let area = Int64(max(0, candidate.width)) * Int64(max(0, candidate.height))
        return Int64(candidate.priority) * 1_000_000 + min(area, 999_999)
    }
}
