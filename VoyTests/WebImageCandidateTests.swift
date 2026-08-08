import Foundation
import Testing
@testable import Voy

struct WebImageCandidateTests {
    @Test func filtersTinyAssetsLogosAndDuplicates() throws {
        let productURL = try #require(URL(string: "https://example.com/product.jpg"))
        let candidates = [
            WebImageCandidate(url: productURL, width: 400, height: 400, description: "", priority: 100),
            WebImageCandidate(url: productURL, width: 1_600, height: 1_200, description: "", priority: 200),
            WebImageCandidate(
                url: try #require(URL(string: "https://example.com/logo.png")),
                width: 800, height: 400, description: "", priority: 10
            ),
            WebImageCandidate(
                url: try #require(URL(string: "https://example.com/pixel.gif")),
                width: 1, height: 1, description: "", priority: 1
            )
        ]

        let filtered = WebImageCandidateProcessor.filtered(candidates)

        #expect(filtered.count == 1)
        #expect(filtered.first?.url == productURL)
        #expect(filtered.first?.width == 1_600)
    }

    @Test func prioritizesOpenGraphCandidatesWithUnknownDimensions() throws {
        let openGraph = WebImageCandidate(
            url: try #require(URL(string: "https://example.com/share.jpg")),
            width: 0, height: 0, description: "", priority: 10_000
        )
        let regular = WebImageCandidate(
            url: try #require(URL(string: "https://example.com/large.jpg")),
            width: 2_000, height: 2_000, description: "", priority: 500
        )

        let filtered = WebImageCandidateProcessor.filtered([regular, openGraph])
        #expect(filtered.first == openGraph)
    }
}
