import DriveStatsCore
import SwiftUI

struct DrivesListView: View {
    let garage: Garage

    @State private var drives: [Drive] = []
    @State private var loadError: String?

    private let store = try? JSONDriveStore(directory: AppPaths.drivesDirectory)

    var body: some View {
        NavigationStack {
            Group {
                if drives.isEmpty {
                    ContentUnavailableView(
                        "No drives yet",
                        systemImage: "car",
                        description: Text(loadError ?? "Recorded drives will appear here.")
                    )
                } else {
                    List {
                        ForEach(drives) { drive in
                            NavigationLink(value: drive.id) {
                                DriveRow(drive: drive, vehicle: garage.vehicle(for: drive.vehicleID))
                            }
                            .contextMenu { vehicleMenu(for: drive) }
                        }
                        .onDelete(perform: delete)
                    }
                    .navigationDestination(for: UUID.self) { driveID in
                        if let drive = drives.first(where: { $0.id == driveID }) {
                            DriveDetailView(
                                drive: drive,
                                vehicleName: garage.vehicle(for: drive.vehicleID)?.displayName
                            )
                        }
                    }
                }
            }
            .navigationTitle("Drives")
        }
        .onAppear(perform: reload)
    }

    @ViewBuilder
    private func vehicleMenu(for drive: Drive) -> some View {
        if !garage.vehicles.isEmpty {
            Menu("Assign vehicle") {
                ForEach(garage.vehicles) { vehicle in
                    Button {
                        assign(vehicle.id, to: drive)
                    } label: {
                        if vehicle.id == drive.vehicleID {
                            Label(vehicle.displayName, systemImage: "checkmark")
                        } else {
                            Text(vehicle.displayName)
                        }
                    }
                }
            }
        }
    }

    private func assign(_ vehicleID: UUID, to drive: Drive) {
        var updated = drive
        updated.vehicleID = vehicleID
        try? store?.save(updated)
        reload()
    }

    private func reload() {
        do {
            guard let store else { throw CocoaError(.fileReadUnknown) }
            drives = try store.loadAll()
            loadError = nil
        } catch {
            loadError = "Could not load drives: \(error.localizedDescription)"
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            try? store?.delete(id: drives[index].id)
        }
        drives.remove(atOffsets: offsets)
    }
}

private struct DriveRow: View {
    let drive: Drive
    let vehicle: Vehicle?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(drive.startedAt, format: .dateTime.day().month().hour().minute())
                    .font(.headline)
                Spacer()
                if let vehicle {
                    VehicleIconView(vehicle: vehicle, size: 13)
                    Text(vehicle.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Unassigned")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            HStack(spacing: 12) {
                Label(Format.kilometers(drive.distanceMeters), systemImage: "road.lanes")
                Label(Format.duration(drive.duration), systemImage: "clock")
                Label(
                    Format.kilometersPerHour(drive.topSpeedMetersPerSecond) + " km/h",
                    systemImage: "gauge.with.needle"
                )
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    DrivesListView(garage: Garage())
}
