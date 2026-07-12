import DriveStatsCore
import SwiftUI

/// The little car icon: the generated cartoon when one exists, otherwise
/// the vehicle's emoji.
struct VehicleIconView: View {
    let vehicle: Vehicle
    var size: CGFloat = 24

    private let generated: UIImage?

    init(vehicle: Vehicle, size: CGFloat = 24) {
        self.vehicle = vehicle
        self.size = size
        generated = VehicleIconStore.load(for: vehicle.id)
    }

    var body: some View {
        if let generated {
            Image(uiImage: generated)
                .resizable()
                .scaledToFit()
                .frame(width: size * 1.6, height: size * 1.2)
        } else {
            Text(vehicle.emoji)
                .font(.system(size: size))
        }
    }
}

/// The emoji offered in the vehicle editor (any emoji can also be typed).
enum VehicleEmoji {
    static let suggestions: [String] = [
        "🚗", "🚙", "🏎️", "🛻", "🚐", "🚕",
        "🚓", "🚌", "🚚", "🏍️", "🛵", "🚜",
    ]
}
