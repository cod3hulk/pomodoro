import AppKit
import Combine
import Foundation
import PomodoroCore
import SwiftUI

@MainActor
final class TimerStore: ObservableObject {
    @Published private(set) var engine: TimerEngine
    @Published var tickEnabled: Bool { didSet { UserDefaults.standard.set(tickEnabled, forKey: "tickEnabled") } }
    @Published var tickVolume: Double {
        didSet {
            let clamped = min(1, max(0, tickVolume))
            if clamped != tickVolume { tickVolume = clamped; return }
            UserDefaults.standard.set(tickVolume, forKey: "tickVolume")
            sound.volume = Float(tickVolume)
        }
    }
    @Published var focusMinutes: Int { didSet { updateSettings() } }
    @Published var shortMinutes: Int { didSet { updateSettings() } }
    @Published var longMinutes: Int { didSet { updateSettings() } }
    @Published var longBreakEvery: Int { didSet { updateSettings() } }
    @Published private(set) var now = Date()
    @Published var durationText: String

    private var timer: Timer?
    private var lastTickSecond: Int?
    private let sound = TickSound()
    private var overlay: NSWindow?

    init(engine initialEngine: TimerEngine? = nil) {
        let defaults = UserDefaults.standard
        let focus = initialEngine.map { Int($0.settings.focus / 60) }
            ?? defaults.object(forKey: "focusMinutes") as? Int ?? 25
        let short = initialEngine.map { Int($0.settings.shortBreak / 60) }
            ?? defaults.object(forKey: "shortMinutes") as? Int ?? 5
        let long = initialEngine.map { Int($0.settings.longBreak / 60) }
            ?? defaults.object(forKey: "longMinutes") as? Int ?? 15
        let every = initialEngine?.settings.longBreakEvery
            ?? defaults.object(forKey: "longBreakEvery") as? Int ?? 4
        durationText = initialEngine.map {
            String(Int($0.settings.duration(for: $0.nextPhase ?? $0.phase) / 60))
        } ?? String(focus)
        focusMinutes = focus
        shortMinutes = short
        longMinutes = long
        longBreakEvery = every
        tickEnabled = defaults.object(forKey: "tickEnabled") as? Bool ?? true
        tickVolume = min(1, max(0, defaults.object(forKey: "tickVolume") as? Double ?? 1))
        engine = initialEngine ?? TimerEngine(settings: TimerSettings(focus: Double(focus * 60),
            shortBreak: Double(short * 60), longBreak: Double(long * 60),
            longBreakEvery: every))
        sound.volume = Float(tickVolume)
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    var remaining: TimeInterval { engine.remaining(at: now) }
    var canEditSettings: Bool { engine.isIdle }
    var sessionPhase: Phase { engine.nextPhase ?? engine.phase }
    var canEditDuration: Bool { engine.isIdle || engine.nextPhase != nil }
    var durationSeconds: TimeInterval? {
        guard let minutes = Int(durationText.trimmingCharacters(in: .whitespacesAndNewlines)),
              (1...180).contains(minutes) else { return nil }
        return Double(minutes * 60)
    }

    private func resetDurationInput() {
        durationText = String(Int(engine.settings.duration(for: sessionPhase) / 60))
    }
    var timeLabel: String {
        let seconds = Int(ceil(remaining))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
    var menuBarTitle: String {
        if let next = engine.nextPhase { return "◉ \(next.title)" }
        return "\(engine.isRunning ? "●" : "◯") \(timeLabel)"
    }

    func selectMode(focus: Bool) {
        guard engine.isIdle else { return }
        engine.selectPhase(focus ? .focus : engine.recommendedBreak)
        resetDurationInput()
        now = .now
        lastTickSecond = nil
    }

    func toggle() {
        if engine.isRunning { engine.pause(at: .now) }
        else if engine.isIdle {
            guard let duration = durationSeconds else { return }
            engine.startSession(duration: duration, at: .now)
        } else { engine.start(at: .now) }
        now = .now
        lastTickSecond = Int(ceil(remaining))
        objectWillChange.send()
    }

    func playTickPreview() { sound.play() }

    func skipBreak() {
        engine.skipPendingBreak()
        resetDurationInput()
        closeOverlay()
        now = .now
        lastTickSecond = nil
        objectWillChange.send()
    }

    func confirmNextPhase() {
        guard let duration = durationSeconds else { return }
        engine.confirmNextPhase(duration: duration, at: .now)
        closeOverlay()
        now = .now
        lastTickSecond = Int(ceil(remaining))
        objectWillChange.send()
    }

    func reset() {
        engine.reset()
        resetDurationInput()
        closeOverlay()
        now = .now
        lastTickSecond = nil
        objectWillChange.send()
    }

    func resetCycle() {
        engine.resetCycle()
        resetDurationInput()
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
        guard engine.isIdle else { return }
        let defaults = UserDefaults.standard
        defaults.set(focusMinutes, forKey: "focusMinutes")
        defaults.set(shortMinutes, forKey: "shortMinutes")
        defaults.set(longMinutes, forKey: "longMinutes")
        defaults.set(longBreakEvery, forKey: "longBreakEvery")
        engine.settings = TimerSettings(focus: Double(focusMinutes * 60),
            shortBreak: Double(shortMinutes * 60), longBreak: Double(longMinutes * 60),
            longBreakEvery: longBreakEvery)
        if engine.phase != .focus {
            engine.selectPhase(engine.recommendedBreak)
        }
        resetDurationInput()
        objectWillChange.send()
    }

    private func refresh() {
        let oldSecond = lastTickSecond
        now = .now
        if let next = engine.advance(to: now) {
            resetDurationInput()
            lastTickSecond = nil
            objectWillChange.send()
            showOverlay(for: next)
            sound.play()
        } else if engine.isRunning {
            let newSecond = Int(ceil(remaining))
            if let oldSecond, newSecond < oldSecond, tickEnabled, engine.phase == .focus,
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
