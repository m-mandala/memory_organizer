import SwiftUI
import Photos

@main
struct MemoryOrganizerApp: App {
    @State private var viewModel = LibraryViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(viewModel)
                .onAppear {
                    Task {
                        await viewModel.requestPermissions()
                    }
                }
        }
    }
}
