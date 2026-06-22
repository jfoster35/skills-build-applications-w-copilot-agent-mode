import SwiftUI

/// Minimal settings presented as a modal sheet (PRD §10).
struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Flash", isOn: $settings.flashOn)
                }

                Section("Saving") {
                    HStack {
                        Text("Album Name")
                        Spacer()
                        TextField("Album Name", text: $settings.albumName)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.secondary)
                    }
                    Toggle("Save Original", isOn: $settings.saveOriginal)
                }

                Section("Detection") {
                    Picker("Detection Sensitivity", selection: $settings.sensitivity) {
                        ForEach(DetectionSensitivity.allCases) { level in
                            Text(level.label).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                    Toggle("Auto Enhancement", isOn: $settings.autoEnhancement)
                }

                Section {
                    Text(appVersion)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .listRowBackground(Color.clear)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
    }
}
