import SwiftUI

/// Root view. Owns app settings and presents the Scan screen.
struct ContentView: View {
    @StateObject private var settings = AppSettings()

    var body: some View {
        ScanView(settings: settings)
    }
}

#Preview {
    ContentView()
}
