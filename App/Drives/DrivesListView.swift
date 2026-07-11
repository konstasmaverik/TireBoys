import DriveStatsCore
import SwiftUI

struct DrivesListView: View {
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
                            DriveRow(drive: drive)
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("Drives")
        }
        .onAppear(perform: reload)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(drive.startedAt, format: .dateTime.day().month().hour().minute())
                .font(.headline)
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
    DrivesListView()
}
