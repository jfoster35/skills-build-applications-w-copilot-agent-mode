import CoreGraphics
import Vision

/// The four corners of a detected rectangle, in Vision's normalized coordinate
/// space (0...1, origin at the bottom-left of the image).
struct DetectedRectangle: Equatable {
    var topLeft: CGPoint
    var topRight: CGPoint
    var bottomRight: CGPoint
    var bottomLeft: CGPoint

    init(observation: VNRectangleObservation) {
        self.topLeft = observation.topLeft
        self.topRight = observation.topRight
        self.bottomRight = observation.bottomRight
        self.bottomLeft = observation.bottomLeft
    }

    init(topLeft: CGPoint, topRight: CGPoint, bottomRight: CGPoint, bottomLeft: CGPoint) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomRight = bottomRight
        self.bottomLeft = bottomLeft
    }

    /// Average corner-to-corner distance from another detection. Used to decide
    /// whether the rectangle has been "stable" between frames.
    func maxCornerDelta(to other: DetectedRectangle) -> CGFloat {
        func d(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
            hypot(a.x - b.x, a.y - b.y)
        }
        return max(
            d(topLeft, other.topLeft),
            d(topRight, other.topRight),
            d(bottomRight, other.bottomRight),
            d(bottomLeft, other.bottomLeft)
        )
    }
}

/// The live state of rectangle detection, consumed by the overlay.
enum DetectionState: Equatable {
    /// No qualifying rectangle in frame — show nothing.
    case none
    /// A rectangle is visible but not yet stable — show a white dashed border.
    case detecting(DetectedRectangle)
    /// Criteria met and the stability timer is counting — show the animated
    /// green border. `progress` goes 0...1 toward auto-capture.
    case locked(DetectedRectangle, progress: Double)

    var rectangle: DetectedRectangle? {
        switch self {
        case .none: return nil
        case .detecting(let r): return r
        case .locked(let r, _): return r
        }
    }
}
