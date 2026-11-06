import SwiftUI

/// Foto profilo Letterboxd; se manca, un cerchio arancione con l'iniziale del nome.
struct ProfileAvatar: View {
    let name: String?
    let url: URL?
    var size: CGFloat = 32
    /// Spenta (grigia e trasparente), per esempio un amico escluso stasera.
    var isDimmed = false

    var body: some View {
        AsyncImage(url: url, transaction: Transaction(animation: .smooth)) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else {
                initials
            }
        }
        .frame(width: size, height: size)
        .clipShape(.circle)
        .overlay { Circle().strokeBorder(.primary.opacity(0.1), lineWidth: 0.5) }
        .saturation(isDimmed ? 0 : 1)
        .opacity(isDimmed ? 0.5 : 1)
        .animation(.snappy, value: isDimmed)
        .accessibilityHidden(true)
    }

    private var initials: some View {
        Group {
            if let initial = name?.first {
                Text(String(initial).uppercased())
            } else {
                Image(systemName: "person.fill")
            }
        }
        .font(.system(size: size * 0.44, weight: .semibold))
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.orange.gradient)
    }
}
