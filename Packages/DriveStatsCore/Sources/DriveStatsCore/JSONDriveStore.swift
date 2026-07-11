import Foundation

/// Drive persistence, newest first. See JSONObjectStore for the storage model.
public struct JSONDriveStore: Sendable {
    private let store: JSONObjectStore<Drive>

    public init(directory: URL) throws {
        store = try JSONObjectStore(directory: directory)
    }

    public func save(_ drive: Drive) throws {
        try store.save(drive)
    }

    public func loadAll() throws -> [Drive] {
        try store.loadAll().sorted { $0.startedAt > $1.startedAt }
    }

    public func delete(id: UUID) throws {
        try store.delete(id: id)
    }
}
