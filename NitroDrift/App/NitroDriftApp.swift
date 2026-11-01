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
                .onAppear {
                    #if DEBUG
                    // An explicit test-only launch argument lets GitHub Actions
                    // screenshot actual rainy gameplay instead of the menu.
                    if ProcessInfo.processInfo.arguments.contains("-ndAutomatedDrive"),
                       session.phase == .menu {
                        session.start(.freeRide)
                    }
                    #endif
                }
        }
    }
}
