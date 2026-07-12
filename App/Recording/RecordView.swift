import SwiftUI

struct RecordView: View {
    @Bindable var model: RecordingViewModel
    @Bindable var garage: Garage

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
            vehiclePicker
            autoDetectToggle
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
    private var vehiclePicker: some View {
        if garage.vehicles.isEmpty {
            Text("Add a vehicle in the Garage tab so drives get tagged.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            Picker(selection: $garage.activeVehicleID) {
                ForEach(garage.vehicles) { vehicle in
                    Label(vehicle.displayName, systemImage: vehicle.bodyStyle.symbolName)
                        .tag(UUID?.some(vehicle.id))
                }
            } label: {
                Label("Vehicle", systemImage: "car")
            }
            .pickerStyle(.menu)
            .disabled(model.isRecording)
        }
    }

    @ViewBuilder
    private var autoDetectToggle: some View {
        if model.isAutoDetectSupported {
            VStack(spacing: 4) {
                Toggle("Auto-detect drives", isOn: $model.isAutoDetectEnabled)
                    .disabled(model.isDenied)
                if model.isAutoDetectEnabled, !model.isRecording {
                    Text("Recording starts automatically when driving is detected.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
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
    RecordView(model: RecordingViewModel(), garage: Garage())
}
