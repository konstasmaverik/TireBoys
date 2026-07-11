import SwiftUI

struct ContentView: View {
    let recorder: RecordingViewModel
    let garage: Garage

    var body: some View {
        TabView {
            RecordView(model: recorder, garage: garage)
                .tabItem { Label("Record", systemImage: "record.circle") }
            DrivesListView(garage: garage)
                .tabItem { Label("Drives", systemImage: "list.bullet") }
            StatsView(garage: garage)
                .tabItem { Label("Stats", systemImage: "chart.bar") }
            GarageView(garage: garage)
                .tabItem { Label("Garage", systemImage: "car.2") }
        }
    }
}

#Preview {
    ContentView(recorder: RecordingViewModel(), garage: Garage())
}
