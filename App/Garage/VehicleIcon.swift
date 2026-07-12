import CoreImage
import UIKit
import Vision

/// Cuts the subject (the car) out of a photo using the same on-device
/// subject-lifting model as the Photos app. Free, offline, iOS 17+.
enum VehicleIconMaker {
    static func makeIcon(from photo: UIImage) async -> UIImage? {
        let input = photo.resized(maxDimension: 1024)
        guard let cgImage = input.cgImage else { return nil }

        return await Task.detached(priority: .userInitiated) { () -> UIImage? in
            let request = VNGenerateForegroundInstanceMaskRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage)
            guard (try? handler.perform([request])) != nil,
                  let observation = request.results?.first,
                  let buffer = try? observation.generateMaskedImage(
                      ofInstances: observation.allInstances,
                      from: handler,
                      croppedToInstancesExtent: true
                  )
            else { return nil }

            let ciImage = CIImage(cvPixelBuffer: buffer)
            let context = CIContext()
            guard let cutout = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
            return UIImage(cgImage: cutout).resized(maxDimension: 256)
        }.value
    }
}

/// Local storage for vehicle icons: one PNG (with transparency) per vehicle.
/// Icons stay on-device; only the owner sees their garage.
enum VehicleIconStore {
    private static var directory: URL {
        URL.documentsDirectory.appending(path: "VehicleIcons", directoryHint: .isDirectory)
    }

    private static func fileURL(for vehicleID: UUID) -> URL {
        directory.appendingPathComponent("\(vehicleID.uuidString).png")
    }

    static func load(for vehicleID: UUID) -> UIImage? {
        guard let data = try? Data(contentsOf: fileURL(for: vehicleID)) else { return nil }
        return UIImage(data: data)
    }

    static func save(_ icon: UIImage, for vehicleID: UUID) {
        guard let data = icon.pngData() else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: fileURL(for: vehicleID), options: .atomic)
    }

    static func delete(for vehicleID: UUID) {
        try? FileManager.default.removeItem(at: fileURL(for: vehicleID))
    }
}
