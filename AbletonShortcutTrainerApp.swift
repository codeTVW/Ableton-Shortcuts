import SwiftUI

@main
struct AbletonShortcutTrainerApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
        }
        .commands {
            CommandMenu("Trainer") {
                Button("Start Daily Session") {
                    store.startDailySession()
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])

                Button("Skip Current Shortcut") {
                    store.skipCurrent()
                }
                .keyboardShortcut(.rightArrow, modifiers: [.command])
            }
        }
    }
}
