import SwiftUI

@main
struct PomodoroApp: App {
    @StateObject private var timer = TimerStore()

    var body: some Scene {
        MenuBarExtra {
            TimerView(store: timer)
        } label: {
            Text(timer.menuBarTitle)
        }
        .menuBarExtraStyle(.window)
    }
}
