import SwiftUI

/// Lightning-bolt torch toggle (PRD §7.4). Highlighted yellow when ON.
struct FlashToggleButton: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            Image(systemName: isOn ? "bolt.fill" : "bolt.slash.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(isOn ? .yellow : .white)
                .frame(width: 44, height: 44)
                .background(.black.opacity(0.35), in: Circle())
        }
        .accessibilityLabel(isOn ? "Flash on" : "Flash off")
    }
}
