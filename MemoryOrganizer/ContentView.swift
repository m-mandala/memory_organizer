import SwiftUI

struct ContentView: View {
    @Environment(LibraryViewModel.self) private var viewModel

    var body: some View {
        TabView {
            Tab("Home", systemImage: "house.fill") {
                HomeView()
            }
            Tab("Duplicates", systemImage: "doc.on.doc.fill") {
                DuplicatesView()
            }
            Tab("Bursts", systemImage: "burst.fill") {
                BurstsView()
            }
            Tab("AI Clusters", systemImage: "sparkles.rectangle.stack.fill") {
                AIClusterView()
            }
        }
    }
}
