import AVFoundation
import CoreImage
import UIKit

/// Owns the AVCaptureSession: configures the camera, streams video frames out
/// for Vision analysis, hands back a full-resolution frame on capture, and
/// controls the torch.
///
/// NOTE (on-device tuning): capture uses the live video frame so it shares the
/// exact coordinate space as the rectangle observation that triggered it. For
/// higher fidelity later, swap to AVCapturePhotoOutput (see CLAUDE.md).
final class CameraService: NSObject, ObservableObject {

    enum Status {
        case unconfigured
        case configured
        case unauthorized
        case failed
    }

    /// The capture session, exposed so the SwiftUI preview layer can attach.
    let session = AVCaptureSession()

    @Published var status: Status = .unconfigured

    /// Called on a background queue for every analyzed video frame.
    var onFrame: ((CVPixelBuffer) -> Void)?

    private let sessionQueue = DispatchQueue(label: "PhotoScanner.session")
    private let videoQueue = DispatchQueue(label: "PhotoScanner.video")
    private let videoOutput = AVCaptureVideoDataOutput()
    private var videoDevice: AVCaptureDevice?

    /// Set transiently when a capture is requested; the next frame fulfils it.
    private var pendingCapture: ((CIImage) -> Void)?

    // MARK: - Lifecycle

    func start() {
        checkAuthorization()
        sessionQueue.async { [weak self] in
            guard let self, self.status == .configured else { return }
            if !self.session.isRunning { self.session.startRunning() }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    // MARK: - Authorization + configuration

    private func checkAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureIfNeeded()
        case .notDetermined:
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }
                if granted {
                    self.configureIfNeeded()
                } else {
                    DispatchQueue.main.async { self.status = .unauthorized }
                }
                self.sessionQueue.resume()
            }
        default:
            DispatchQueue.main.async { self.status = .unauthorized }
        }
    }

    private func configureIfNeeded() {
        sessionQueue.async { [weak self] in
            guard let self, self.status == .unconfigured else { return }
            self.configure()
        }
    }

    private func configure() {
        session.beginConfiguration()
        session.sessionPreset = .hd1920x1080

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else {
            session.commitConfiguration()
            DispatchQueue.main.async { self.status = .failed }
            return
        }
        session.addInput(input)
        videoDevice = device

        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        guard session.canAddOutput(videoOutput) else {
            session.commitConfiguration()
            DispatchQueue.main.async { self.status = .failed }
            return
        }
        session.addOutput(videoOutput)

        if let connection = videoOutput.connection(with: .video) {
            // Portrait orientation so buffers arrive upright for Vision + Core Image.
            if #available(iOS 17.0, *) {
                connection.videoRotationAngle = 90
            } else {
                connection.videoOrientation = .portrait
            }
        }

        session.commitConfiguration()
        DispatchQueue.main.async { self.status = .configured }
    }

    // MARK: - Capture

    /// Request the next available frame as a CIImage (delivered on the video queue).
    func captureFrame(_ completion: @escaping (CIImage) -> Void) {
        videoQueue.async { [weak self] in
            self?.pendingCapture = completion
        }
    }

    // MARK: - Torch

    func setTorch(_ on: Bool) {
        sessionQueue.async { [weak self] in
            guard let device = self?.videoDevice, device.hasTorch else { return }
            do {
                try device.lockForConfiguration()
                device.torchMode = on ? .on : .off
                device.unlockForConfiguration()
            } catch {
                // Torch unavailable (e.g. overheating) — fail silently for MVP.
            }
        }
    }
}

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // Fulfil a pending capture with this exact frame, then resume streaming.
        if let pending = pendingCapture {
            pendingCapture = nil
            let image = CIImage(cvPixelBuffer: pixelBuffer)
            pending(image)
            return
        }

        onFrame?(pixelBuffer)
    }
}
