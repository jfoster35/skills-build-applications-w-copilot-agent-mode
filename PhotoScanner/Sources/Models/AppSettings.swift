import Foundation
import Combine

/// Detection sensitivity maps to the Vision confidence threshold (PRD §10).
enum DetectionSensitivity: String, CaseIterable, Identifiable {
    case low, medium, high

    var id: String { rawValue }

    var label: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }

    /// Minimum VNDetectRectanglesRequest confidence.
    var confidenceThreshold: Float {
        switch self {
        case .low: return 0.75
        case .medium: return 0.85
        case .high: return 0.95
        }
    }
}

/// App-wide settings, persisted to UserDefaults and shared across views/services.
final class AppSettings: ObservableObject {
    private enum Keys {
        static let albumName = "albumName"
        static let saveOriginal = "saveOriginal"
        static let sensitivity = "detectionSensitivity"
        static let autoEnhancement = "autoEnhancement"
    }

    /// Flash/torch is session state (PRD default OFF), mirrored between the
    /// Scan screen and Settings. Not persisted across launches.
    @Published var flashOn: Bool = false

    @Published var albumName: String {
        didSet { defaults.set(albumName, forKey: Keys.albumName) }
    }
    @Published var saveOriginal: Bool {
        didSet { defaults.set(saveOriginal, forKey: Keys.saveOriginal) }
    }
    @Published var sensitivity: DetectionSensitivity {
        didSet { defaults.set(sensitivity.rawValue, forKey: Keys.sensitivity) }
    }
    @Published var autoEnhancement: Bool {
        didSet { defaults.set(autoEnhancement, forKey: Keys.autoEnhancement) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.albumName = defaults.string(forKey: Keys.albumName) ?? "Photo Scanner"
        self.saveOriginal = defaults.bool(forKey: Keys.saveOriginal)        // default OFF
        self.autoEnhancement = defaults.object(forKey: Keys.autoEnhancement) as? Bool ?? true // default ON
        let raw = defaults.string(forKey: Keys.sensitivity) ?? DetectionSensitivity.medium.rawValue
        self.sensitivity = DetectionSensitivity(rawValue: raw) ?? .medium
    }
}
