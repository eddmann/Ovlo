import SwiftUI

/// Horizontal tab picker for selecting between session types.
struct SessionTypePicker: View {
    @Binding var selected: SessionType

    private let accentCyan = Color(red: 0.25, green: 0.95, blue: 0.88)

    var body: some View {
        HStack(spacing: 0) {
            ForEach(SessionType.allCases) { type in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selected = type
                    }
                } label: {
                    Text(type.rawValue)
                        .font(.subheadline)
                        .fontWeight(selected == type ? .semibold : .regular)
                        .foregroundStyle(selected == type ? accentCyan : .white.opacity(0.5))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .background(
                            Capsule()
                                .fill(selected == type ? Color.white.opacity(0.15) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.08))
        )
    }
}

#Preview {
    @Previewable @State var selected: SessionType = .breathe

    ZStack {
        Color(red: 0.02, green: 0.08, blue: 0.18)
            .ignoresSafeArea()
        SessionTypePicker(selected: $selected)
    }
}
