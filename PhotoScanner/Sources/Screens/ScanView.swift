import SwiftUI

/// The root, full-screen camera scanning experience (PRD §7).
struct ScanView: View {
    @ObservedObject var settings: AppSettings
    @StateObject private var viewModel: ScanViewModel

    @State private var showSettings = false
    @State private var selectedScan: ScannedPhoto?

    init(settings: AppSettings) {
        _settings = ObservedObject(wrappedValue: settings)
        _viewModel = StateObject(wrappedValue: ScanViewModel(settings: settings))
    }

    var body: some View {
        ZStack {
            Color(red: 0x1C / 255, green: 0x1C / 255, blue: 0x1E / 255)
                .ignoresSafeArea()

            if viewModel.cameraAuthorized {
                cameraLayer
            } else {
                PermissionDeniedView(
                    message: "Camera access is needed to scan your photos.",
                    action: viewModel.openSystemSettings
                )
            }
        }
        .statusBarHidden(true)
        .onAppear { viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
        .sheet(isPresented: $showSettings) {
            SettingsView(settings: settings)
        }
        .fullScreenCover(item: $selectedScan) { scan in
            PhotoPreviewView(scan: scan)
        }
    }

    // MARK: - Camera layer

    private var cameraLayer: some View {
        ZStack {
            CameraPreview(session: viewModel.camera.session)
                .ignoresSafeArea()

            DetectionOverlay(state: viewModel.detectionState)

            // Brief white flash on capture.
            Color.white
                .ignoresSafeArea()
                .opacity(viewModel.captureFlash ? 0.8 : 0)
                .animation(.easeOut(duration: 0.18), value: viewModel.captureFlash)

            VStack {
                topControls
                if viewModel.photoLibraryDenied { photoDeniedBanner }
                Spacer()
                if let toast = viewModel.toast { ToastView(text: toast) }
                ThumbnailStrip(scans: viewModel.scans) { selectedScan = $0 }
            }
        }
    }

    private var topControls: some View {
        HStack(spacing: 12) {
            Spacer()
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.35), in: Circle())
            }
            .accessibilityLabel("Settings")

            FlashToggleButton(isOn: $settings.flashOn)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var photoDeniedBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text("Photo Library access denied. Scans can't be saved.")
                .font(.footnote)
            Spacer()
            Button("Settings", action: viewModel.openSystemSettings)
                .font(.footnote.weight(.semibold))
        }
        .padding(10)
        .foregroundColor(.white)
        .background(.red.opacity(0.85), in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

/// Full-screen permission-denied message with a jump to iOS Settings.
struct PermissionDeniedView: View {
    let message: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.metering.unknown")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.7))
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
                .padding(.horizontal, 40)
            Button("Open Settings", action: action)
                .buttonStyle(.borderedProminent)
        }
    }
}

/// Brief bottom toast notification (PRD §11).
struct ToastView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.black.opacity(0.8), in: Capsule())
            .padding(.bottom, 8)
            .transition(.opacity)
    }
}
