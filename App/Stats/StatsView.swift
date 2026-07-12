import DriveStatsCore
import SwiftUI

struct StatsView: View {
    let garage: Garage

    @State private var drives: [Drive] = []
    @State private var period: Period = .allTime
    @State private var vehicleFilterID: UUID?
    @AppStorage(Format.useMilesKey) private var useMiles = false

    private let store = try? JSONDriveStore(directory: AppPaths.drivesDirectory)

    enum Period: String, CaseIterable, Identifiable {
        case week = "7 days"
        case month = "30 days"
        case allTime = "All time"

        var id: Self { self }

        var cutoff: Date? {
            switch self {
            case .week: Calendar.current.date(byAdding: .day, value: -7, to: Date())
            case .month: Calendar.current.date(byAdding: .day, value: -30, to: Date())
            case .allTime: nil
            }
        }
    }

    private var filteredDrives: [Drive] {
        drives.filter { drive in
            if let cutoff = period.cutoff, drive.startedAt < cutoff { return false }
            if let vehicleFilterID, drive.vehicleID != vehicleFilterID { return false }
            return true
        }
    }

    private var summary: DriveSummary {
        DriveSummary.compute(from: filteredDrives)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Picker("Period", selection: $period) {
                        ForEach(Period.allCases) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)

                    statCards
                }
                .padding()
            }
            .navigationTitle("Stats")
            .toolbar {
                vehicleFilterMenu
                Menu {
                    Toggle("Use miles", isOn: $useMiles)
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
        .onAppear(perform: reload)
    }

    private var statCards: some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                card("Distance", Format.distance(summary.totalDistanceMeters), "road.lanes")
                card("Time in car", Format.duration(summary.totalDuration), "clock")
            }
            GridRow {
                card("Top speed", Format.speedWithUnit(summary.topSpeedMetersPerSecond), "gauge.with.needle")
                card("Drives", String(summary.driveCount), "point.bottomleft.forward.to.point.topright.scurvepath")
            }
            GridRow {
                card("Longest drive", Format.distance(summary.longestDriveMeters), "arrow.up.right")
                    .gridCellColumns(2)
            }
        }
    }

    private func card(_ label: String, _ value: String, _ systemImage: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.bold().monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }

    private var vehicleFilterMenu: some View {
        Menu {
            Picker("Vehicle", selection: $vehicleFilterID) {
                Text("All vehicles").tag(UUID?.none)
                ForEach(garage.vehicles) { vehicle in
                    Text(vehicle.displayName).tag(UUID?.some(vehicle.id))
                }
            }
        } label: {
            Label(
                garage.vehicle(for: vehicleFilterID)?.displayName ?? "All vehicles",
                systemImage: "car"
            )
        }
    }

    private func reload() {
        drives = (try? store?.loadAll()) ?? []
    }
}

#Preview {
    StatsView(garage: Garage())
}
