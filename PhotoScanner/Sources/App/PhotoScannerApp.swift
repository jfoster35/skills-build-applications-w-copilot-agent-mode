import SwiftUI

@main
struct PhotoScannerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark) // PRD §13: dark default reduces glare
        }
    }
}
