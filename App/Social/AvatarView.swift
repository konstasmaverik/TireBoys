import SwiftUI

/// Circular profile picture with the username's initial as fallback.
struct AvatarView: View {
    let urlString: String?
    let fallbackName: String
    var size: CGFloat = 32

    var body: some View {
        Group {
            if let urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    initialCircle
                }
            } else {
                initialCircle
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var initialCircle: some View {
        Circle()
            .fill(.quaternary)
            .overlay {
                Text(fallbackName.prefix(1).uppercased())
                    .font(.system(size: size * 0.45, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
    }
}
