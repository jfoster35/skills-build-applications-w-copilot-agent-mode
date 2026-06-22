import Vision
import CoreVideo
import CoreGraphics
import QuartzCore

/// Runs continuous rectangle detection on camera frames and tracks stability.
///
/// Emits a `DetectionState` for the overlay, and fires `onStableCapture` once a
/// qualifying rectangle has held still for `requiredStableDuration`.
final class VisionService {

    // Tuning constants (PRD §7.2).
    private let minimumSize: Float = 0.30          // ≥30% of frame
    private let aspectMin: Float = 0.6             // ~3:2 .. 4:3, allowing either orientation
    private let aspectMax: Float = 1.7
    private let requiredStableDuration: CFTimeInterval = 1.0
    /// Max normalized corner movement still considered "stable" between frames.
    private let stabilityTolerance: CGFloat = 0.02

    /// Vision confidence threshold; updated live from settings.
    var confidenceThreshold: Float = 0.85

    /// Delivered on the main queue whenever the detection state changes.
    var onStateChange: ((DetectionState) -> Void)?
    /// Delivered on the main queue once the rectangle is stable long enough.
    /// Carries the corners used to trigger capture.
    var onStableCapture: ((DetectedRectangle) -> Void)?

    private var stableSince: CFTimeInterval?
    private var lastRectangle: DetectedRectangle?
    private var captureArmed = true

    /// Pause detection (e.g. while a capture is being processed).
    func suspend() {
        captureArmed = false
        reset()
    }

    /// Resume detecting the next photo.
    func resume() {
        captureArmed = true
        reset()
    }

    private func reset() {
        stableSince = nil
        lastRectangle = nil
        emit(.none)
    }

    /// Analyze one frame. Call from the camera's video queue.
    func process(pixelBuffer: CVPixelBuffer) {
        guard captureArmed else { return }

        let request = VNDetectRectanglesRequest()
        request.minimumConfidence = confidenceThreshold
        request.minimumSize = minimumSize
        request.minimumAspectRatio = aspectMin
        request.maximumAspectRatio = aspectMax
        request.maximumObservations = 1

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return
        }

        guard let observation = (request.results as? [VNRectangleObservation])?.first else {
            stableSince = nil
            lastRectangle = nil
            emit(.none)
            return
        }

        let rect = DetectedRectangle(observation: observation)
        let now = CACurrentMediaTime()

        if let previous = lastRectangle, rect.maxCornerDelta(to: previous) <= stabilityTolerance {
            // Still holding steady.
            if stableSince == nil { stableSince = now }
            let elapsed = now - (stableSince ?? now)
            let progress = min(elapsed / requiredStableDuration, 1.0)
            emit(.locked(rect, progress: progress))

            if elapsed >= requiredStableDuration {
                captureArmed = false
                emitCapture(rect)
            }
        } else {
            // Moved too much — restart the stability timer.
            stableSince = now
            emit(.detecting(rect))
        }

        lastRectangle = rect
    }

    private func emit(_ state: DetectionState) {
        DispatchQueue.main.async { [weak self] in self?.onStateChange?(state) }
    }

    private func emitCapture(_ rect: DetectedRectangle) {
        DispatchQueue.main.async { [weak self] in self?.onStableCapture?(rect) }
    }
}
