import Testing
import UIKit
@testable import Voy

struct ImageFileProcessorTests {
    @Test func centersExtractedSubjectsOnSquareCanvas() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let subject = UIGraphicsImageRenderer(size: CGSize(width: 800, height: 400), format: format).image { context in
            UIColor.systemOrange.setFill()
            context.fill(CGRect(x: 250, y: 100, width: 300, height: 200))
        }

        let canvasData = try PhotoNormalizer.squareCanvasData(for: subject)
        let canvas = try #require(UIImage(data: canvasData))

        #expect(canvas.size == CGSize(width: 1_200, height: 1_200))
        #expect(canvasData.starts(with: [0x89, 0x50, 0x4E, 0x47]))
    }

    @Test func createsBoundedDisplayAndThumbnailImages() async throws {
        let source = UIGraphicsImageRenderer(size: CGSize(width: 2_400, height: 1_200)).image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2_400, height: 1_200))
        }
        let data = try #require(source.jpegData(compressionQuality: 1))

        let prepared = try await ImageFileProcessor.prepare(data)
        let display = try #require(UIImage(data: prepared.displayData))
        let thumbnail = try #require(UIImage(data: prepared.thumbnailData))
        let original = try #require(UIImage(data: prepared.originalData))

        #expect(max(display.size.width, display.size.height) <= 1_800)
        #expect(max(thumbnail.size.width, thumbnail.size.height) <= 480)
        #expect(max(original.size.width, original.size.height) <= 3_000)
    }
}
