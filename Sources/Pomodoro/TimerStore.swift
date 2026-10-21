import AppKit
import Combine
import Foundation
import PomodoroCore
import SwiftUI

@MainActor
final class TimerStore: ObservableObject {
    @Published private(set) var engine: TimerEngine
    @Published var tickEnabled: Bool { didSet { UserDefaults.standard.set(tickEnabled, forKey: "tickEnabled") } }
    @Published var focusMinutes: Int { didSet { updateSettings() } }
    @Published var shortMinutes: Int { didSet { updateSettings() } }
    @Published var longMinutes: Int { didSet { updateSettings() } }
    @Published var longBreakEvery: Int { didSet { updateSettings() } }
    @Published private(set) var now = Date()

    private var timer: Timer?
    private var lastTickSecond: Int?
    private let sound = TickSound()
    private var overlay: NSWindow?

    init() {
        let defaults = UserDefaults.standard
        let focus = defaults.object(forKey: "focusMinutes") as? Int ?? 25
        let short = defaults.object(forKey: "shortMinutes") as? Int ?? 5
        let long = defaults.object(forKey: "longMinutes") as? Int ?? 15
        let every = defaults.object(forKey: "longBreakEvery") as? Int ?? 4
        focusMinutes = focus
        shortMinutes = short
        longMinutes = long
        longBreakEvery = every
        tickEnabled = defaults.object(forKey: "tickEnabled") as? Bool ?? true
        engine = TimerEngine(settings: TimerSettings(focus: Double(focus * 60),
            shortBreak: Double(short * 60), longBreak: Double(long * 60),
            longBreakEvery: every))
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    var remaining: TimeInterval { engine.remaining(at: now) }
    var canEditSettings: Bool { !engine.isRunning && engine.nextPhase == nil &&
        remaining == engine.settings.duration(for: engine.phase) }
    var timeLabel: String {
        let seconds = Int(ceil(remaining))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
    var menuBarTitle: String {
        if let next = engine.nextPhase { return "◉ \(next.title)" }
        return "\(engine.isRunning ? "●" : "◯") \(timeLabel)"
    }

    func toggle() {
        if engine.isRunning { engine.pause(at: .now) }
        else { engine.start(at: .now) }
        now = .now
        lastTickSecond = Int(ceil(remaining))
        objectWillChange.send()
    }

    func confirmNextPhase() {
        engine.confirmNextPhase(at: .now)
        closeOverlay()
        now = .now
        lastTickSecond = Int(ceil(remaining))
        objectWillChange.send()
    }

    func reset() {
        engine.reset()
        closeOverlay()
        now = .now
        lastTickSecond = nil
        objectWillChange.send()
    }

    func resetCycle() {
        engine.resetCycle()
        closeOverlay()
        now = .now
        lastTickSecond = nil
        objectWillChange.send()
    }

    func closeOverlay() {
        overlay?.close()
        overlay = nil
    }

    private func updateSettings() {
        guard !engine.isRunning, engine.nextPhase == nil else { return }
        let defaults = UserDefaults.standard
        defaults.set(focusMinutes, forKey: "focusMinutes")
        defaults.set(shortMinutes, forKey: "shortMinutes")
        defaults.set(longMinutes, forKey: "longMinutes")
        defaults.set(longBreakEvery, forKey: "longBreakEvery")
        engine.settings = TimerSettings(focus: Double(focusMinutes * 60),
            shortBreak: Double(shortMinutes * 60), longBreak: Double(longMinutes * 60),
            longBreakEvery: longBreakEvery)
        objectWillChange.send()
    }

    private func refresh() {
        let oldSecond = lastTickSecond
        now = .now
        if let next = engine.advance(to: now) {
            lastTickSecond = nil
            objectWillChange.send()
            showOverlay(for: next)
            sound.play()
        } else if engine.isRunning {
            let newSecond = Int(ceil(remaining))
            if let oldSecond, newSecond < oldSecond, tickEnabled,
               newSecond > 0, oldSecond - newSecond == 1 { sound.play() }
            lastTickSecond = newSecond
        }
    }

    private func showOverlay(for phase: Phase) {
        closeOverlay()
        let frame = NSScreen.main?.frame ?? NSScreen.screens.first?.frame
            ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        let window = NSWindow(contentRect: frame, styleMask: [.borderless],
                              backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.collectionBehavior = .moveToActiveSpace
        window.level = .screenSaver
        window.backgroundColor = .black
        window.contentView = NSHostingView(rootView: TransitionView(phase: phase,
            start: { [weak self] in self?.confirmNextPhase() },
            later: { [weak self] in self?.closeOverlay() }))
        overlay = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }
}
