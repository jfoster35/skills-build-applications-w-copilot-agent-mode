import Foundation
import Combine
import UIKit
import CoreImage
import AudioToolbox
import Photos

/// Coordinates the capture loop: camera frames → Vision detection → Core Image
/// pipeline → Photos save → thumbnail strip. Keeps the UI responsive by doing
/// all processing off the main thread.
final class ScanViewModel: ObservableObject {

    // UI-facing state (mutated on the main thread only).
    @Published var detectionState: DetectionState = .none
    @Published private(set) var scans: [ScannedPhoto] = []
    @Published var cameraAuthorized: Bool = true
    @Published var photoLibraryDenied: Bool = false
    @Published var captureFlash: Bool = false
    @Published var toast: String?

    let camera = CameraService()
    let settings: AppSettings

    private let vision = VisionService()
    private let processing = ImageProcessingService()
    private let library = PhotoLibraryService()
    private let processingQueue = DispatchQueue(label: "PhotoScanner.processing", qos: .userInitiated)

    private var cancellables = Set<AnyCancellable>()
    private var didConfigure = false
    private var toastWorkItem: DispatchWorkItem?

    init(settings: AppSettings) {
        self.settings = settings
    }

    // MARK: - Lifecycle

    func onAppear() {
        configureOnce()
        camera.start()
        camera.setTorch(settings.flashOn)
        Task { await requestPhotoAccess() }
    }

    func onDisappear() {
        camera.stop()
    }

    private func configureOnce() {
        guard !didConfigure else { return }
        didConfigure = true

        vision.confidenceThreshold = settings.sensitivity.confidenceThreshold

        camera.onFrame = { [weak self] pixelBuffer in
            self?.vision.process(pixelBuffer: pixelBuffer)
        }
        vision.onStateChange = { [weak self] state in
            self?.detectionState = state
        }
        vision.onStableCapture = { [weak self] rectangle in
            self?.handleStableCapture(rectangle)
        }

        camera.$status
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.cameraAuthorized = (status != .unauthorized)
            }
            .store(in: &cancellables)

        settings.$sensitivity
            .sink { [weak self] sensitivity in
                self?.vision.confidenceThreshold = sensitivity.confidenceThreshold
            }
            .store(in: &cancellables)

        settings.$flashOn
            .sink { [weak self] on in
                self?.camera.setTorch(on)
            }
            .store(in: &cancellables)
    }

    private func requestPhotoAccess() async {
        let status = await library.requestAuthorization()
        await MainActor.run {
            self.photoLibraryDenied = (status == .denied || status == .restricted)
        }
    }

    // MARK: - Capture pipeline

    private func handleStableCapture(_ rectangle: DetectedRectangle) {
        // Soft shutter sound + brief flash animation.
        AudioServicesPlaySystemSound(1108)
        captureFlash = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
            self?.captureFlash = false
        }

        // Snapshot settings now so the background pipeline doesn't touch shared state.
        let autoEnhance = settings.autoEnhancement
        let saveOriginal = settings.saveOriginal
        let album = settings.albumName

        camera.captureFrame { [weak self] rawImage in
            self?.processingQueue.async {
                self?.runPipeline(rawImage: rawImage,
                                  rectangle: rectangle,
                                  autoEnhance: autoEnhance,
                                  saveOriginal: saveOriginal,
                                  album: album)
            }
        }
    }

    private func runPipeline(rawImage: CIImage,
                             rectangle: DetectedRectangle,
                             autoEnhance: Bool,
                             saveOriginal: Bool,
                             album: String) {
        var enhancementSkipped = false
        let result: ImageProcessingService.Result

        do {
            result = try processing.process(rawImage: rawImage,
                                            rectangle: rectangle,
                                            autoEnhancement: autoEnhance,
                                            includeOriginal: saveOriginal)
        } catch {
            // Processing failure → fall back to a faithful (un-enhanced) crop.
            enhancementSkipped = true
            do {
                result = try processing.process(rawImage: rawImage,
                                                rectangle: rectangle,
                                                autoEnhancement: false,
                                                includeOriginal: false)
            } catch {
                finish(toast: "Could not save photo. Check storage.")
                return
            }
        }

        guard let url = writeTempFile(result.enhanced) else {
            finish(toast: "Could not save photo. Check storage.")
            return
        }

        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.library.save(image: result.enhanced, toAlbumNamed: album)
                if let original = result.original {
                    try? await self.library.save(image: original, toAlbumNamed: album)
                }
                let scan = ScannedPhoto(thumbnail: result.thumbnail, fullImageURL: url)
                await MainActor.run {
                    self.scans.append(scan)
                    if enhancementSkipped { self.showToast("Enhancement skipped.") }
                    self.resumeDetection()
                }
            } catch {
                await MainActor.run {
                    self.showToast("Could not save photo. Check storage.")
                    self.resumeDetection()
                }
            }
        }
    }

    private func finish(toast message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.showToast(message)
            self?.resumeDetection()
        }
    }

    private func resumeDetection() {
        vision.resume()
    }

    // MARK: - Helpers

    private func writeTempFile(_ image: UIImage) -> URL? {
        guard let data = image.jpegData(compressionQuality: 0.95) else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func showToast(_ message: String) {
        toast = message
        toastWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.toast = nil }
        toastWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: item)
    }
}
