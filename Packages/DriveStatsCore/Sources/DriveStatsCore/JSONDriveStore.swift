import Foundation

/// Offline-first persistence: one JSON file per drive in a local directory.
/// No database dependency keeps this Linux-testable and trivially syncable
/// later (upload file contents, mark synced).
public struct JSONDriveStore: Sendable {
    private let directory: URL

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    public init(directory: URL) throws {
        self.directory = directory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    public func save(_ drive: Drive) throws {
        let data = try Self.makeEncoder().encode(drive)
        try data.write(to: fileURL(for: drive.id), options: .atomic)
    }

    /// Newest first. A corrupt file is skipped rather than failing the whole
    /// list — losing one drive's display beats losing access to all of them.
    public func loadAll() throws -> [Drive] {
        let files = try FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "json" }

        let decoder = Self.makeDecoder()
        return files
            .compactMap { url in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? decoder.decode(Drive.self, from: data)
            }
            .sorted { $0.startedAt > $1.startedAt }
    }

    public func delete(id: UUID) throws {
        let url = fileURL(for: id)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    private func fileURL(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).json")
    }
}
