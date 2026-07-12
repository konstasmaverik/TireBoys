import DriveStatsCore
import SwiftUI

/// The little car glyph: an SF Symbols silhouette in the car's paint color.
struct VehicleIconView: View {
    let vehicle: Vehicle
    var size: CGFloat = 24

    var body: some View {
        Image(systemName: vehicle.bodyStyle.symbolName)
            .font(.system(size: size))
            .foregroundStyle(Color(hex: vehicle.colorHex))
    }
}

extension Vehicle.BodyStyle {
    var symbolName: String {
        switch self {
        case .sedan: "car.side.fill"
        case .suv: "suv.side.fill"
        case .sports: "convertible.side.fill"
        case .pickup: "truck.pickup.side.fill"
        }
    }

    var label: String {
        switch self {
        case .sedan: "Sedan"
        case .suv: "SUV"
        case .sports: "Sports"
        case .pickup: "Pickup"
        }
    }
}

/// The paint colors offered in the vehicle editor.
enum VehiclePaint {
    static let palette: [String] = [
        "#D0312D", // red
        "#F47B20", // orange
        "#F7C948", // yellow
        "#3F8F3D", // green
        "#2D68C4", // blue
        "#7D4CB8", // purple
        "#1C1C1E", // black
        "#9BA0A8", // silver
        "#F2F2F4", // white
    ]
}

extension Color {
    init(hex: String) {
        var value: UInt64 = 0
        Scanner(string: String(hex.dropFirst(hex.hasPrefix("#") ? 1 : 0))).scanHexInt64(&value)
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
