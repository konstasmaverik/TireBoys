import SwiftUI

struct RecordView: View {
    @State private var model = RecordingViewModel()

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            speedHUD
            statsGrid
            Spacer()
            if let saveError = model.saveError {
                Text(saveError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
            controlButton
        }
        .padding()
        .onAppear {
            if model.authorizationStatus == .notDetermined {
                model.requestPermission()
            }
        }
    }

    private var speedHUD: some View {
        VStack(spacing: 4) {
            Text(Format.kilometersPerHour(model.currentSpeedMetersPerSecond))
                .font(.system(size: 96, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text("km/h")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private var statsGrid: some View {
        Grid(horizontalSpacing: 24, verticalSpacing: 8) {
            GridRow {
                stat(label: "Distance", value: Format.kilometers(model.accumulator?.distanceMeters ?? 0))
                stat(label: "Top speed", value: Format.kilometersPerHour(model.accumulator?.topSpeedMetersPerSecond ?? 0) + " km/h")
                durationStat
            }
        }
    }

    private var durationStat: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let elapsed = model.isRecording
                ? context.date.timeIntervalSince(model.accumulator?.startedAt ?? context.date)
                : 0
            stat(label: "Duration", value: Format.duration(elapsed))
        }
    }

    private func stat(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline.monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var controlButton: some View {
        if model.isDenied {
            VStack(spacing: 8) {
                Text("Location access is required to record drives.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    Link("Open Settings", destination: settingsURL)
                }
            }
        } else {
            Button {
                model.isRecording ? model.stopDrive() : model.startDrive()
            } label: {
                Label(
                    model.isRecording ? "Stop Drive" : "Start Drive",
                    systemImage: model.isRecording ? "stop.circle.fill" : "record.circle"
                )
                .font(.title2.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(model.isRecording ? .red : .accentColor)
            .disabled(!model.isAuthorized)
        }
    }
}

#Preview {
    RecordView()
}
