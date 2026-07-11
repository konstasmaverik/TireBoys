import SwiftUI

@main
struct DriveStatsApp: App {
    // Owned here, not by RecordView: when iOS relaunches the app in the
    // background (significant-change wake), App.init still runs, so the
    // model can re-arm auto-detection without the UI ever appearing.
    @State private var recorder = RecordingViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(recorder: recorder)
        }
    }
}
