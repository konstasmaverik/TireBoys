import DriveStatsCore
import SwiftUI

/// The little car icon: just the vehicle's emoji, sized to fit its context.
struct VehicleIconView: View {
    let vehicle: Vehicle
    var size: CGFloat = 24

    var body: some View {
        Text(vehicle.emoji)
            .font(.system(size: size))
    }
}

/// The emoji offered in the vehicle editor (any emoji can also be typed).
enum VehicleEmoji {
    static let suggestions: [String] = [
        "🚗", "🚙", "🏎️", "🛻", "🚐", "🚕",
        "🚓", "🚌", "🚚", "🏍️", "🛵", "🚜",
    ]
}
