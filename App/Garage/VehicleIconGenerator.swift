import CoreImage
import DriveStatsCore
import UIKit
import Vision

/// Turns a photo of the user's car into a cartoon icon:
/// 1. The car is subject-lifted out of the photo on-device and its paint
///    color measured — the photo itself never leaves the phone.
/// 2. pollinations.ai (free, keyless) generates a cartoon from a text
///    prompt like "red 1998 Toyota Supra".
/// 3. The cartoon's background is removed on-device and the result stored
///    locally next to the vehicle.
enum VehicleIconGenerator {
    enum GenerationError: LocalizedError {
        case badImage
        case serviceFailed

        var errorDescription: String? {
            switch self {
            case .badImage: "Couldn't read that photo."
            case .serviceFailed: "The icon service didn't respond — try again."
            }
        }
    }

    /// Detects the car's paint color from the photo, on-device. The result
    /// is shown to the user, who can correct it before generating.
    static func detectPaint(of photo: UIImage) async -> String? {
        guard photo.cgImage != nil else { return nil }
        let subject = await subjectCutout(of: photo) ?? photo
        return colorName(of: subject)
    }

    static func generateIcon(for vehicle: Vehicle, paint: String) async throws -> UIImage {
        // The color is stated twice: the generator weighs early and repeated
        // words more, and paint color is what users notice first.
        let prompt = "cute flat emoji sticker of a \(paint) \(vehicle.year) \(vehicle.make) \(vehicle.model) car with \(paint) paint, side view, simple rounded cartoon, thick outline, plain white background, no text"
        guard let encoded = prompt.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://image.pollinations.ai/prompt/\(encoded)?width=512&height=512&nologo=true&seed=\(Int.random(in: 0..<100_000))")
        else { throw GenerationError.serviceFailed }

        var request = URLRequest(url: url)
        request.timeoutInterval = 60
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let cartoon = UIImage(data: data)
        else { throw GenerationError.serviceFailed }

        // Cut the cartoon off its background so it sits like an emoji.
        let icon = await subjectCutout(of: cartoon) ?? cartoon
        return icon.resized(maxDimension: 256)
    }

    /// Apple's on-device subject lifting (the Photos sticker effect).
    private static func subjectCutout(of image: UIImage) async -> UIImage? {
        let input = image.resized(maxDimension: 1024)
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
            return UIImage(cgImage: cutout)
        }.value
    }

    /// Dominant paint color of the cutout. Averaging fails on cars —
    /// windows, tires, and shadows drag the mean toward grey — so this
    /// buckets saturated pixels by hue and takes the biggest bucket,
    /// falling back to black/silver/white when the body is unsaturated.
    private static func colorName(of image: UIImage) -> String? {
        let sample = 64
        guard let cgImage = image.resized(maxDimension: CGFloat(sample)).cgImage else { return nil }

        let width = cgImage.width, height = cgImage.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &pixels, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let hueNames = ["red", "orange", "yellow", "green", "blue", "purple", "pink"]
        var hueWeight = [Double](repeating: 0, count: hueNames.count)
        var opaque = 0.0, saturatedWeight = 0.0
        var brightnessValues: [Double] = []

        for i in stride(from: 0, to: pixels.count, by: 4) where pixels[i + 3] > 128 {
            opaque += 1
            var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0
            UIColor(
                red: CGFloat(pixels[i]) / 255,
                green: CGFloat(pixels[i + 1]) / 255,
                blue: CGFloat(pixels[i + 2]) / 255,
                alpha: 1
            ).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil)
            brightnessValues.append(brightness)

            // Glass, chrome, tires, and shadows are unsaturated or too dark
            // to be paint; skip them for the hue vote.
            guard saturation > 0.25, brightness > 0.15 else { continue }
            let weight = Double(saturation * brightness)
            saturatedWeight += weight

            let bucket = switch hue * 360 {
            case ..<15, 345...: 0
            case ..<42: 1
            case ..<70: 2
            case ..<165: 3
            case ..<255: 4
            case ..<300: 5
            default: 6
            }
            hueWeight[bucket] += weight
        }
        guard opaque > 0 else { return nil }

        // A colored car shows plenty of saturated paint; a black/white/silver
        // car doesn't, and its few saturated pixels are reflections.
        if saturatedWeight >= opaque * 0.06,
           let best = hueWeight.indices.max(by: { hueWeight[$0] < hueWeight[$1] }) {
            return hueNames[best]
        }

        let median = brightnessValues.sorted()[brightnessValues.count / 2]
        if median < 0.25 { return "black" }
        if median < 0.7 { return "silver" }
        return "white"
    }
}

/// Local storage for generated icons: one PNG per vehicle, on-device only.
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
