import SwiftUI

/// Draws the detected-photo boundary over the camera feed (PRD §7.3).
///
/// On-device tuning note: corners come from Vision in the full-frame coordinate
/// space, while the preview uses `.resizeAspectFill` (which crops). For pixel-
/// perfect alignment, map through `AVCaptureVideoPreviewLayer`'s coordinate
/// conversion helpers. This straightforward mapping is a good starting point.
struct DetectionOverlay: View {
    let state: DetectionState

    private let accent = Color(red: 0x4C / 255, green: 0xAF / 255, blue: 0x50 / 255)

    var body: some View {
        GeometryReader { geo in
            switch state {
            case .none:
                EmptyView()

            case .detecting(let rect):
                path(for: rect, in: geo.size)
                    .stroke(Color.white.opacity(0.9),
                            style: StrokeStyle(lineWidth: 2, dash: [8, 6]))

            case .locked(let rect, let progress):
                ZStack {
                    // Faint full outline...
                    path(for: rect, in: geo.size)
                        .stroke(accent.opacity(0.35), lineWidth: 3)
                    // ...with a green stroke that fills toward auto-capture.
                    path(for: rect, in: geo.size)
                        .trim(from: 0, to: progress)
                        .stroke(accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .shadow(color: accent.opacity(0.6), radius: 6)
                }
                .animation(.linear(duration: 0.1), value: progress)
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    /// Build a quad path from Vision-normalized corners (origin bottom-left).
    private func path(for rect: DetectedRectangle, in size: CGSize) -> Path {
        func point(_ p: CGPoint) -> CGPoint {
            CGPoint(x: p.x * size.width, y: (1 - p.y) * size.height)
        }
        var path = Path()
        path.move(to: point(rect.topLeft))
        path.addLine(to: point(rect.topRight))
        path.addLine(to: point(rect.bottomRight))
        path.addLine(to: point(rect.bottomLeft))
        path.closeSubpath()
        return path
    }
}
