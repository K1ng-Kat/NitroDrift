import SwiftUI

@main
struct NitroDriftApp: App {
    @StateObject private var session = GameSession()

    var body: some Scene {
        WindowGroup {
            NitroDriftRootView()
                .environmentObject(session)
                .preferredColorScheme(.dark)
                .statusBarHidden()
        }
    }
}
