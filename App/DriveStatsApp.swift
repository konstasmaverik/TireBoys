import BackgroundTasks
import SwiftUI

@main
struct DriveStatsApp: App {
    // Owned here, not by RecordView: when iOS relaunches the app in the
    // background (significant-change wake), App.init still runs, so the
    // model can re-arm auto-detection without the UI ever appearing.
    @State private var garage: Garage
    @State private var recorder: RecordingViewModel
    @State private var backend: Backend

    @Environment(\.scenePhase) private var scenePhase

    private static let refreshTaskID = "com.drivestats.refresh"

    init() {
        let garage = Garage()
        let recorder = RecordingViewModel()
        let backend = Backend()
        recorder.vehicleIDProvider = { garage.activeVehicleID }
        recorder.onDriveSaved = { Task { await backend.syncLocalDrives() } }
        _garage = State(initialValue: garage)
        _recorder = State(initialValue: recorder)
        _backend = State(initialValue: backend)

        // Free-Apple-ID apps have no push; periodic background refresh plus
        // local notifications is the substitute. iOS decides the cadence.
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.refreshTaskID, using: nil) { task in
            Self.scheduleBackgroundRefresh()
            let work = Task { @MainActor in
                await backend.checkGroupActivity()
                task.setTaskCompleted(success: true)
            }
            task.expirationHandler = { work.cancel() }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(recorder: recorder, garage: garage, backend: backend)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                Self.scheduleBackgroundRefresh()
            case .active:
                Task { await backend.checkGroupActivity() }
            default:
                break
            }
        }
    }

    private static func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}
