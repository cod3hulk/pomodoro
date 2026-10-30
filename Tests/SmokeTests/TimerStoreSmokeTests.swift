import Foundation
import PomodoroCore

/// Runs in its own executable, not inside the installed app. No audio playback,
/// windows, or real application preferences are changed.
@main
struct TimerStoreSmokeTests {
    @MainActor
    static func main() {
        // This standalone executable must never share the installed app's domain.
        let preferencesDomain = ProcessInfo.processInfo.processName
        precondition(preferencesDomain == "store-smoke-tests" && Bundle.main.bundleIdentifier == nil)
        let defaults = UserDefaults.standard
        defaults.setPersistentDomain([
            "focusMinutes": 25, "shortMinutes": 5, "longMinutes": 15,
            "longBreakEvery": 4, "tickEnabled": false,
        ], forName: preferencesDomain)
        defer { defaults.removePersistentDomain(forName: preferencesDomain) }

        let store = TimerStore()
        var checks = 0
        var failures: [String] = []
        func check(_ condition: Bool, _ message: String) {
            checks += 1
            if !condition { failures.append(message) }
        }
        check(store.durationText == String(store.focusMinutes), "Initial focus default")
        check(store.canEditDuration, "Idle duration is editable")
        store.selectMode(focus: false)
        check(store.sessionPhase == .shortBreak, "Initial Break selects short break")
        check(store.durationText == String(store.shortMinutes), "Break default")
        for text in ["", "0", "-1", "181", "1.5", "abc", "999999999999999999999999"] {
            store.durationText = text
            check(store.durationSeconds == nil, "Invalid input rejected: \(text)")
            store.toggle()
            check(!store.engine.isRunning, "Invalid input must not start")
        }
        store.durationText = " 7 "
        check(store.durationSeconds == 420, "Whitespace accepted")
        store.toggle()
        check(store.engine.isRunning, "Custom break starts")
        check(abs(store.remaining - 420) < 1, "Custom break duration")
        check(!store.canEditDuration, "Running duration not editable")
        store.selectMode(focus: true)
        check(store.sessionPhase == .shortBreak, "Running phase protected")
        store.toggle()
        check(!store.engine.isRunning && !store.canEditDuration, "Paused state protected")
        store.toggle()
        check(store.engine.isRunning, "Resume preserves timer")
        store.reset()
        check(store.durationText == String(store.shortMinutes), "Reset restores break default")
        store.selectMode(focus: true)
        check(store.durationText == String(store.focusMinutes), "Switch restores focus default")
        let original = store.focusMinutes
        store.durationText = original == 10 ? "11" : "10"
        store.toggle()
        check(store.engine.isQuickSession, "Edited focus retains quick policy")
        check(store.focusMinutes == original, "Saved focus unchanged")
        store.reset()
        check(store.durationText == String(original), "Reset restores focus default")
        store.durationText = String(original)
        store.toggle()
        check(!store.engine.isQuickSession, "Default focus counts normally")
        for (oldCadence, newCadence, oldPhase, newPhase) in [
            (4, 1, Phase.shortBreak, Phase.longBreak),
            (1, 4, Phase.longBreak, Phase.shortBreak),
        ] {
            let label = "Cadence \(oldCadence) → \(newCadence)"
            var engine = TimerEngine(settings: TimerSettings(
                focus: 30 * 60, shortBreak: 3 * 60, longBreak: 12 * 60,
                longBreakEvery: oldCadence))
            let start = Date(timeIntervalSince1970: 1_000)
            engine.start(at: start)
            engine.advance(to: start.addingTimeInterval(engine.settings.focus))
            engine.skipPendingBreak()
            let breakStore = TimerStore(engine: engine)
            check(breakStore.focusMinutes == 30 && breakStore.shortMinutes == 3
                && breakStore.longMinutes == 12 && breakStore.longBreakEvery == oldCadence,
                "\(label): injected settings populate fields")
            breakStore.selectMode(focus: false)
            check(breakStore.sessionPhase == oldPhase, "\(label): initial break")
            breakStore.durationText = "9"
            breakStore.longBreakEvery = newCadence
            check(breakStore.engine.recommendedBreak == newPhase, "\(label): recommendation changes")
            check(breakStore.sessionPhase == newPhase, "\(label): selected break follows recommendation")
            let expectedSeconds = engine.settings.duration(for: newPhase)
            check(breakStore.durationText == String(Int(expectedSeconds / 60)),
                "\(label): duration input follows recommended break")
            check(breakStore.remaining == expectedSeconds, "\(label): remaining follows recommended break")
            check(breakStore.engine.isIdle && breakStore.engine.nextPhase == nil,
                "\(label): settings do not start or queue a session")
            check(breakStore.engine.completedFocusSessions == 1, "\(label): cycle progress preserved")
            breakStore.toggle()
            check(breakStore.engine.phase == newPhase && breakStore.engine.isRunning,
                "\(label): starts recommended break")
            check(abs(breakStore.remaining - expectedSeconds) < 1,
                "\(label): starts with recommended duration")
        }
        if !failures.isEmpty {
            // Clean up even on the deliberately failing RED run.
            defaults.removePersistentDomain(forName: preferencesDomain)
            fatalError(failures.joined(separator: "\n"))
        }
        print("\(checks) TimerStore smoke checks passed")
    }
}
