import DriveStatsCore
import MapKit
import SwiftUI

/// The route stays on-device: this renders local points only.
struct DriveDetailView: View {
    let drive: Drive
    let vehicleName: String?

    private var coordinates: [CLLocationCoordinate2D] {
        drive.points.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            statsHeader
                .padding()
            if coordinates.count >= 2 {
                routeMap
            } else {
                ContentUnavailableView(
                    "No route recorded",
                    systemImage: "map",
                    description: Text("This drive has no GPS trace.")
                )
            }
        }
        .navigationTitle(drive.startedAt.formatted(.dateTime.day().month().hour().minute()))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var statsHeader: some View {
        Grid(horizontalSpacing: 24, verticalSpacing: 8) {
            GridRow {
                stat("Distance", Format.kilometers(drive.distanceMeters))
                stat("Duration", Format.duration(drive.duration))
                stat("Top speed", Format.kilometersPerHour(drive.topSpeedMetersPerSecond) + " km/h")
            }
            if let vehicleName {
                GridRow {
                    stat("Vehicle", vehicleName)
                        .gridCellColumns(3)
                }
            }
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline.monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var routeMap: some View {
        Map(initialPosition: .automatic, interactionModes: [.pan, .zoom]) {
            MapPolyline(coordinates: coordinates)
                .stroke(.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            if let start = coordinates.first {
                Annotation("Start", coordinate: start) {
                    Circle().fill(.green)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                }
            }
            if let end = coordinates.last {
                Annotation("End", coordinate: end) {
                    Circle().fill(.red)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                }
            }
        }
    }
}
