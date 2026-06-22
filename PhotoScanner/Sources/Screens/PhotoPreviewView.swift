import SwiftUI

/// Full-screen preview of a single scan (PRD §9). Enhanced image only.
/// Dismiss with the X button or a downward swipe.
struct PhotoPreviewView: View {
    let scan: ScannedPhoto
    @Environment(\.dismiss) private var dismiss

    @State private var fullImage: UIImage?
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Group {
                if let image = fullImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                } else {
                    // Fall back to the thumbnail while the full image loads.
                    Image(uiImage: scan.thumbnail)
                        .resizable()
                        .scaledToFit()
                        .blur(radius: 8)
                        .overlay(ProgressView().tint(.white))
                }
            }
            .offset(y: dragOffset)

            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(.black.opacity(0.4), in: Circle())
                    }
                    .accessibilityLabel("Close")
                    .padding(16)
                }
                Spacer()
            }
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = max(0, value.translation.height)
                }
                .onEnded { value in
                    if value.translation.height > 120 {
                        dismiss()
                    } else {
                        withAnimation(.spring()) { dragOffset = 0 }
                    }
                }
        )
        .task {
            fullImage = await loadFullImage()
        }
    }

    private func loadFullImage() async -> UIImage? {
        let url = scan.fullImageURL
        return await Task.detached(priority: .userInitiated) {
            guard let data = try? Data(contentsOf: url) else { return nil }
            return UIImage(data: data)
        }.value
    }
}
