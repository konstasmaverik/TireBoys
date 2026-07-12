import SwiftUI

@main
struct DriveStatsApp: App {
    // Owned here, not by RecordView: when iOS relaunches the app in the
    // background (significant-change wake), App.init still runs, so the
    // model can re-arm auto-detection without the UI ever appearing.
    @State private var garage: Garage
    @State private var recorder: RecordingViewModel
    @State private var backend: Backend

    init() {
        let garage = Garage()
        let recorder = RecordingViewModel()
        let backend = Backend()
        recorder.vehicleIDProvider = { garage.activeVehicleID }
        recorder.onDriveSaved = { Task { await backend.syncLocalDrives() } }
        _garage = State(initialValue: garage)
        _recorder = State(initialValue: recorder)
        _backend = State(initialValue: backend)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(recorder: recorder, garage: garage, backend: backend)
        }
    }
}
