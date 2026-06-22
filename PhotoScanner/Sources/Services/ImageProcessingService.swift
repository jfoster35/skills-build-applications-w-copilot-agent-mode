import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// The Core Image pipeline (PRD §8). Runs off the main thread.
final class ImageProcessingService {

    struct Result {
        let enhanced: UIImage
        /// The raw captured frame, only produced when "Save Original" is on.
        let original: UIImage?
        let thumbnail: UIImage
    }

    enum ProcessingError: Error {
        case renderFailed
    }

    private let context = CIContext(options: [.useSoftwareRenderer: false])

    /// Perspective-correct + crop, then optionally enhance.
    /// - Parameters:
    ///   - rawImage: full captured frame in CIImage space (origin bottom-left).
    ///   - rectangle: detected corners in Vision normalized coordinates.
    ///   - autoEnhancement: when false, skip steps 3–5 (faithful archival output).
    ///   - includeOriginal: also render the untouched capture.
    func process(rawImage: CIImage,
                 rectangle: DetectedRectangle,
                 autoEnhancement: Bool,
                 includeOriginal: Bool) throws -> Result {

        let extent = rawImage.extent

        func denormalize(_ p: CGPoint) -> CGPoint {
            CGPoint(x: extent.origin.x + p.x * extent.width,
                    y: extent.origin.y + p.y * extent.height)
        }

        // Step 1 — Perspective correction (also crops to the quad => Step 2).
        let perspective = CIFilter.perspectiveCorrection()
        perspective.inputImage = rawImage
        perspective.topLeft = denormalize(rectangle.topLeft)
        perspective.topRight = denormalize(rectangle.topRight)
        perspective.bottomRight = denormalize(rectangle.bottomRight)
        perspective.bottomLeft = denormalize(rectangle.bottomLeft)

        guard var image = perspective.outputImage else { throw ProcessingError.renderFailed }
        // Reset origin so downstream extents start at zero.
        image = image.transformed(by: CGAffineTransform(translationX: -image.extent.origin.x,
                                                        y: -image.extent.origin.y))

        if autoEnhancement {
            // Step 3 — Auto enhancement (brightness/contrast/colour balance).
            for filter in image.autoAdjustmentFilters(options: [.enhance: true]) {
                filter.setValue(image, forKey: kCIInputImageKey)
                if let output = filter.outputImage { image = output }
            }

            // Step 4 — Noise reduction (conservative).
            let noise = CIFilter.noiseReduction()
            noise.inputImage = image
            noise.noiseLevel = 0.02
            noise.sharpness = 0.4
            if let output = noise.outputImage { image = output }

            // Step 5 — Gentle sharpening.
            let sharpen = CIFilter.unsharpMask()
            sharpen.inputImage = image
            sharpen.radius = 2.5
            sharpen.intensity = 0.5
            if let output = sharpen.outputImage { image = output }
        }

        let enhanced = try render(image)
        let thumbnail = makeThumbnail(from: enhanced)

        var original: UIImage?
        if includeOriginal {
            original = try? render(rawImage)
        }

        return Result(enhanced: enhanced, original: original, thumbnail: thumbnail)
    }

    private func render(_ image: CIImage) throws -> UIImage {
        let rect = image.extent.isInfinite ? CGRect(x: 0, y: 0, width: 1, height: 1) : image.extent
        guard let cgImage = context.createCGImage(image, from: rect) else {
            throw ProcessingError.renderFailed
        }
        return UIImage(cgImage: cgImage)
    }

    /// Step 7 — Downscale for the thumbnail strip (120x120pt target).
    func makeThumbnail(from image: UIImage, side: CGFloat = 120) -> UIImage {
        let scale = UIScreen.main.scale
        let size = CGSize(width: side, height: side)
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            // Aspect-fill into the square.
            let aspect = image.size.width / image.size.height
            var drawRect = CGRect(origin: .zero, size: size)
            if aspect > 1 {
                drawRect.size.width = size.height * aspect
                drawRect.origin.x = (size.width - drawRect.size.width) / 2
            } else {
                drawRect.size.height = size.width / aspect
                drawRect.origin.y = (size.height - drawRect.size.height) / 2
            }
            image.draw(in: drawRect)
        }
    }
}
