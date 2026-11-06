import AppKit
import Foundation
import PomodoroCore
import SwiftUI
import Darwin

/// Hosts real UI in an offscreen window and an isolated preferences domain.
/// The native-control guard prevents reintroducing the sampled sizing path;
/// short performance measurements alone do not reproduce the long-lived bug.
@main
struct TimerViewSmokeTests {
    @MainActor private static var heartbeat: Timer?

    @MainActor static func main() {
        let domain = ProcessInfo.processInfo.processName
        precondition(domain == "ui-smoke-tests" && Bundle.main.bundleIdentifier == nil)
        let defaults = UserDefaults.standard
        defaults.setPersistentDomain(["tickEnabled": false], forName: domain)
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        let store = TimerStore(engine: TimerEngine())
        let host = NSHostingView(rootView: TimerView(store: store))
        let window = NSWindow(contentRect: NSRect(x: -10_000, y: -10_000, width: 310, height: 400),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.orderBack(nil)

        var checks = 0
        var failures: [String] = []
        func check(_ condition: Bool, _ message: String) {
            checks += 1
            if !condition { failures.append(message) }
        }
        func segmentedControls(in view: NSView) -> Int {
            (view is NSSegmentedControl ? 1 : 0)
                + view.subviews.reduce(0) { $0 + segmentedControls(in: $1) }
        }
        func inspect(_ state: String) {
            host.layoutSubtreeIfNeeded()
            check(segmentedControls(in: host) == 0,
                  "\(state): selector must avoid the native segmented-control sizing path")
        }

        let start = Date()
        let startCPU = clock()
        var beats = 0
        var maxGap = 0.0
        var lastBeat = start
        heartbeat = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            let now = Date()
            maxGap = max(maxGap, now.timeIntervalSince(lastBeat))
            lastBeat = now
            beats += 1
        }
        var step = 0
        let actions = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            MainActor.assumeIsolated {
                switch step {
                case 0:
                    inspect("idle focus")
                    store.selectMode(focus: false)
                case 1:
                    inspect("idle break")
                    check(store.sessionPhase == .shortBreak && store.durationText == "5", "Break default preserved")
                    store.durationText = "7"
                    store.toggle()
                case 2:
                    inspect("running break")
                    check(store.engine.isRunning, "Custom break starts")
                    store.selectMode(focus: true)
                    check(store.sessionPhase == .shortBreak, "Running phase protected")
                    store.toggle()
                case 3:
                    inspect("paused break")
                    check(!store.engine.isRunning && !store.engine.isIdle, "Paused state preserved")
                    store.selectMode(focus: true)
                    check(store.sessionPhase == .shortBreak, "Paused phase protected")
                    store.reset()
                    store.selectMode(focus: true)
                    store.durationText = "2"
                    store.toggle()
                case 4:
                    inspect("running focus")
                    check(store.engine.isRunning && store.engine.phase == .focus, "Focus starts")
                default:
                    timer.invalidate()
                    Self.heartbeat?.invalidate()
                    let elapsed = Date().timeIntervalSince(start)
                    let cpu = Double(clock() - startCPU) / Double(CLOCKS_PER_SEC)
                    check(maxGap < 0.5, "Main-thread heartbeat must remain responsive")
                    check(cpu / elapsed < 0.3, "UI must not saturate a CPU core")
                    print("\(checks) UI checks; \(failures.count) failures; CPU=\(cpu)s / \(elapsed)s; heartbeat max gap=\(maxGap)s; beats=\(beats)")
                    for failure in failures { print("FAIL: \(failure)") }
                    window.orderOut(nil)
                    UserDefaults.standard.removePersistentDomain(forName: domain)
                    exit(failures.isEmpty ? 0 : 1)
                }
                step += 1
            }
        }
        withExtendedLifetime((heartbeat, actions)) { app.run() }
    }
}
