import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            RecordView()
                .tabItem { Label("Record", systemImage: "record.circle") }
            DrivesListView()
                .tabItem { Label("Drives", systemImage: "list.bullet") }
        }
    }
}

#Preview {
    ContentView()
}
