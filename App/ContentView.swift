import SwiftUI
import DriveStatsCore

struct ContentView: View {
    private let sampleKmh = UnitConversion.kilometersPerHour(fromMetersPerSecond: 27.78)

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "car.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("DriveStats")
                .font(.largeTitle.bold())
            Text("Milestone 0 — pipeline proof")
                .foregroundStyle(.secondary)
            Text("Core link check: 27.78 m/s = \(sampleKmh, specifier: "%.1f") km/h")
                .font(.footnote.monospaced())
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
