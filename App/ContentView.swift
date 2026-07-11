import SwiftUI

struct ContentView: View {
    let recorder: RecordingViewModel

    var body: some View {
        TabView {
            RecordView(model: recorder)
                .tabItem { Label("Record", systemImage: "record.circle") }
            DrivesListView()
                .tabItem { Label("Drives", systemImage: "list.bullet") }
        }
    }
}

#Preview {
    ContentView(recorder: RecordingViewModel())
}
