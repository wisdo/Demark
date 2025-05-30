import SwiftUI

@main
struct DemarkExampleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentSize)
#if os(macOS)
        .windowStyle(.titleBar)
#endif
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
