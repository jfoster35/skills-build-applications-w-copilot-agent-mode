import SwiftUI

/// Horizontal strip of session scans pinned to the bottom of the Scan screen
/// (PRD §9). Auto-scrolls to the newest, tap opens a full-screen preview.
struct ThumbnailStrip: View {
    let scans: [ScannedPhoto]
    let onSelect: (ScannedPhoto) -> Void

    var body: some View {
        Group {
            if scans.isEmpty {
                Text("Your scans will appear here")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.5))
                    .frame(maxWidth: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(scans) { scan in
                                Button {
                                    onSelect(scan)
                                } label: {
                                    Image(uiImage: scan.thumbnail)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 80, height: 80)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
                                }
                                .id(scan.id)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .onChange(of: scans.count) { _ in
                        if let last = scans.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .trailing) }
                        }
                    }
                }
            }
        }
        .frame(height: 100)
        .frame(maxWidth: .infinity)
        .background(.black.opacity(0.25))
    }
}
