import DriveStatsCore
import Foundation
import Observation

/// The user's vehicles plus which one drives get tagged with. Shared by the
/// garage tab (editing), the record tab (picking), and lists (name lookup).
@MainActor
@Observable
final class Garage {
    private(set) var vehicles: [Vehicle] = []
    private(set) var loadError: String?

    /// Tagged onto every new drive. Falls back to the default vehicle; the
    /// record screen can point it at another car for the current session.
    var activeVehicleID: UUID?

    private let store: JSONVehicleStore?

    private static let defaultVehicleKey = "defaultVehicleID"

    init() {
        store = try? JSONVehicleStore(directory: AppPaths.vehiclesDirectory)
        reload()
        activeVehicleID = defaultVehicleID ?? vehicles.first?.id
    }

    var defaultVehicleID: UUID? {
        get {
            UserDefaults.standard.string(forKey: Self.defaultVehicleKey).flatMap(UUID.init)
        }
        set {
            UserDefaults.standard.set(newValue?.uuidString, forKey: Self.defaultVehicleKey)
        }
    }

    func vehicle(for id: UUID?) -> Vehicle? {
        vehicles.first { $0.id == id }
    }

    func add(make: String, model: String, year: Int) {
        let vehicle = Vehicle(make: make, model: model, year: year)
        do {
            guard let store else { throw CocoaError(.fileWriteUnknown) }
            try store.save(vehicle)
            reload()
            // The first car in the garage becomes the default automatically.
            if defaultVehicleID == nil {
                defaultVehicleID = vehicle.id
            }
            if activeVehicleID == nil {
                activeVehicleID = vehicle.id
            }
        } catch {
            loadError = "Could not save vehicle: \(error.localizedDescription)"
        }
    }

    func delete(id: UUID) {
        try? store?.delete(id: id)
        VehicleIconStore.delete(for: id)
        reload()
        if defaultVehicleID == id {
            defaultVehicleID = vehicles.first?.id
        }
        if activeVehicleID == id {
            activeVehicleID = defaultVehicleID
        }
    }

    private func reload() {
        do {
            guard let store else { throw CocoaError(.fileReadUnknown) }
            vehicles = try store.loadAll()
            loadError = nil
        } catch {
            loadError = "Could not load vehicles: \(error.localizedDescription)"
        }
    }
}
