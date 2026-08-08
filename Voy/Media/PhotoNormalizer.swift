import CoreImage
import Foundation
import UIKit
import Vision

struct PhotoProcessingResult: Identifiable, Sendable {
    let id = UUID()
    let original: PreparedImage
    let normalized: PreparedImage?
}

enum PhotoNormalizer {
    enum NormalizationError: Error {
        case noForeground
        case renderingFailed
    }

    static func process(_ sourceData: Data) async throws -> PhotoProcessingResult {
        async let originalPreparation = ImageFileProcessor.prepare(sourceData)
        let normalized = try? await extractAndNormalize(sourceData)
        return try await PhotoProcessingResult(
            original: originalPreparation,
            normalized: normalized
        )
    }

    static func squareCanvasData(for extractedImage: UIImage, size: CGFloat = 1_200) throws -> Data {
        guard let cropped = extractedImage.croppedToVisibleContent() else {
            throw NormalizationError.noForeground
        }

        let maximumSubjectDimension = size * 0.80
        let subjectScale = min(
            maximumSubjectDimension / max(cropped.size.width, 1),
            maximumSubjectDimension / max(cropped.size.height, 1)
        )
        let subjectSize = CGSize(
            width: cropped.size.width * subjectScale,
            height: cropped.size.height * subjectScale
        )
        let subjectRect = CGRect(
            x: (size - subjectSize.width) / 2,
            y: (size - subjectSize.height) / 2,
            width: subjectSize.width,
            height: subjectSize.height
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let canvas = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format).image { _ in
            cropped.draw(in: subjectRect)
        }
        guard let data = canvas.pngData() else {
            throw NormalizationError.renderingFailed
        }
        return data
    }

    private static func extractAndNormalize(_ sourceData: Data) async throws -> PreparedImage {
        try await Task.detached(priority: .userInitiated) {
            guard let source = UIImage(data: sourceData), let sourceCGImage = source.normalizedCGImage() else {
                throw ImageFileProcessor.ProcessingError.unreadableImage
            }

            let request = VNGenerateForegroundInstanceMaskRequest()
            let handler = VNImageRequestHandler(cgImage: sourceCGImage, options: [:])
            try handler.perform([request])
            guard let observation = request.results?.first, !observation.allInstances.isEmpty else {
                throw NormalizationError.noForeground
            }

            let maskBuffer = try observation.generateScaledMaskForImage(
                forInstances: observation.allInstances,
                from: handler
            )
            let input = CIImage(cgImage: sourceCGImage)
            let mask = CIImage(cvPixelBuffer: maskBuffer)
            let transparent = CIImage(color: .clear).cropped(to: input.extent)
            guard
                let filter = CIFilter(name: "CIBlendWithMask"),
                let context = Optional(CIContext(options: [.useSoftwareRenderer: false]))
            else {
                throw NormalizationError.renderingFailed
            }
            filter.setValue(input, forKey: kCIInputImageKey)
            filter.setValue(transparent, forKey: kCIInputBackgroundImageKey)
            filter.setValue(mask, forKey: kCIInputMaskImageKey)
            guard
                let output = filter.outputImage,
                let cutoutCGImage = context.createCGImage(output, from: input.extent)
            else {
                throw NormalizationError.renderingFailed
            }

            let cutout = UIImage(cgImage: cutoutCGImage)
            let displayData = try squareCanvasData(for: cutout)
            guard let displayImage = UIImage(data: displayData) else {
                throw NormalizationError.renderingFailed
            }
            let thumbnailData = try squareCanvasData(for: displayImage, size: 480)

            let preparedOriginal = try await ImageFileProcessor.prepare(sourceData)
            return PreparedImage(
                displayData: displayData,
                thumbnailData: thumbnailData,
                originalData: preparedOriginal.originalData
            )
        }.value
    }
}

private extension UIImage {
    func normalizedCGImage() -> CGImage? {
        if imageOrientation == .up, let cgImage {
            return cgImage
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
        return rendered.cgImage
    }

    func croppedToVisibleContent() -> UIImage? {
        guard let sourceCGImage = normalizedCGImage() else { return nil }
        let width = sourceCGImage.width
        let height = sourceCGImage.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.draw(sourceCGImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1
        for y in 0..<height {
            for x in 0..<width {
                let alpha = pixels[y * bytesPerRow + x * bytesPerPixel + 3]
                if alpha > 12 {
                    minX = min(minX, x)
                    maxX = max(maxX, x)
                    minY = min(minY, y)
                    maxY = max(maxY, y)
                }
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }

        let bounds = CGRect(
            x: minX,
            y: minY,
            width: maxX - minX + 1,
            height: maxY - minY + 1
        )
        guard let cropped = sourceCGImage.cropping(to: bounds) else { return nil }
        return UIImage(cgImage: cropped)
    }
}
