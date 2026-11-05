import SwiftUI

@main
struct SmarterboxdApp: App {
    @State private var store = WatchlistStore()

    init() {
        // Cache più ampia per le locandine scaricate da AsyncImage.
        URLCache.shared = URLCache(memoryCapacity: 64 * 1024 * 1024, diskCapacity: 512 * 1024 * 1024)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .tint(.orange)
        }
    }
}
