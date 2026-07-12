import SwiftUI

struct ContentView: View {
    let recorder: RecordingViewModel
    let garage: Garage
    let backend: Backend

    var body: some View {
        TabView {
            RecordView(model: recorder, garage: garage)
                .tabItem { Label("Record", systemImage: "record.circle") }
            DrivesListView(garage: garage)
                .tabItem { Label("Drives", systemImage: "list.bullet") }
            StatsView(garage: garage)
                .tabItem { Label("Stats", systemImage: "chart.bar") }
            SocialView(backend: backend)
                .tabItem { Label("Social", systemImage: "person.2") }
            GarageView(garage: garage)
                .tabItem { Label("Garage", systemImage: "car.2") }
        }
    }
}

#Preview {
    ContentView(recorder: RecordingViewModel(), garage: Garage(), backend: Backend())
}
