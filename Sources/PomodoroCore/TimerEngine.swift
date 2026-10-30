import Foundation

public enum Phase: String, Equatable, Sendable {
    case focus, shortBreak, longBreak

    public var title: String {
        switch self {
        case .focus: "Focus"
        case .shortBreak: "Short break"
        case .longBreak: "Long break"
        }
    }
}

public struct TimerSettings: Equatable, Sendable {
    public var focus: TimeInterval
    public var shortBreak: TimeInterval
    public var longBreak: TimeInterval
    public var longBreakEvery: Int

    public init(focus: TimeInterval = 25 * 60, shortBreak: TimeInterval = 5 * 60,
                longBreak: TimeInterval = 15 * 60, longBreakEvery: Int = 4) {
        self.focus = max(1, focus)
        self.shortBreak = max(1, shortBreak)
        self.longBreak = max(1, longBreak)
        self.longBreakEvery = max(1, longBreakEvery)
    }

    public func duration(for phase: Phase) -> TimeInterval {
        switch phase {
        case .focus: focus
        case .shortBreak: shortBreak
        case .longBreak: longBreak
        }
    }
}

public struct TimerEngine: Sendable {
    public private(set) var phase: Phase = .focus
    public private(set) var nextPhase: Phase?
    public private(set) var completedFocusSessions = 0
    public var settings: TimerSettings
    private var deadline: Date?
    private var pausedRemaining: TimeInterval?
    private var quickDuration: TimeInterval?

    public init(settings: TimerSettings = .init()) { self.settings = settings }
    public var isRunning: Bool { deadline != nil }
    /// True while a one-off focus session with a custom duration is running or paused.
    public var isQuickSession: Bool { quickDuration != nil }

    public func remaining(at now: Date = .now) -> TimeInterval {
        if let deadline { return max(0, deadline.timeIntervalSince(now)) }
        return pausedRemaining ?? settings.duration(for: phase)
    }

    /// Only a fresh/reset timer can change phase; paused or pending sessions are protected.
    public var isIdle: Bool { deadline == nil && pausedRemaining == nil && nextPhase == nil }

    /// Break length is chosen by the cycle, not by a separate UI mode.
    public var recommendedBreak: Phase {
        if let nextPhase, nextPhase != .focus { return nextPhase }
        return completedFocusSessions > 0 && completedFocusSessions % settings.longBreakEvery == 0
            ? .longBreak : .shortBreak
    }

    /// Selects a session without starting it or changing cycle progress.
    public mutating func selectPhase(_ phase: Phase) {
        guard isIdle else { return }
        self.phase = phase
    }

    public mutating func start(at now: Date = .now) {
        guard deadline == nil, nextPhase == nil else { return }
        deadline = now.addingTimeInterval(pausedRemaining ?? settings.duration(for: phase))
        pausedRemaining = nil
    }

    /// A one-off duration never updates saved settings. Edited focus sessions keep
    /// the quick-focus policy (no long-break credit); default focus counts normally.
    public mutating func startSession(duration: TimeInterval, at now: Date = .now) {
        guard isIdle, duration.isFinite, duration > 0 else { return }
        if phase == .focus && duration != settings.focus {
            startFocus(duration: duration, at: now)
        } else {
            deadline = now.addingTimeInterval(duration)
        }
    }

    /// Starts a one-off focus session of `duration` seconds. Only valid while idle
    /// in focus. It leaves `settings` untouched and does not count toward the
    /// long-break cycle.
    public mutating func startFocus(duration: TimeInterval, at now: Date = .now) {
        guard duration > 0, phase == .focus, deadline == nil,
              pausedRemaining == nil, nextPhase == nil else { return }
        quickDuration = duration
        deadline = now.addingTimeInterval(duration)
    }

    public mutating func pause(at now: Date = .now) {
        guard deadline != nil else { return }
        pausedRemaining = remaining(at: now)
        deadline = nil
    }

    @discardableResult public mutating func advance(to now: Date = .now) -> Phase? {
        guard let deadline, now >= deadline else { return nil }
        self.deadline = nil
        pausedRemaining = nil
        if phase == .focus {
            if quickDuration != nil {
                nextPhase = .shortBreak
            } else {
                completedFocusSessions += 1
                nextPhase = completedFocusSessions % settings.longBreakEvery == 0 ? .longBreak : .shortBreak
            }
            quickDuration = nil
        } else {
            nextPhase = .focus
        }
        return nextPhase
    }

    public mutating func confirmNextPhase(duration: TimeInterval? = nil, at now: Date = .now) {
        guard let nextPhase else { return }
        let duration = duration ?? settings.duration(for: nextPhase)
        guard duration.isFinite, duration > 0 else { return }
        phase = nextPhase
        self.nextPhase = nil
        pausedRemaining = nil
        startSession(duration: duration, at: now)
    }

    /// Declines a pending break and returns to idle focus without starting a timer.
    public mutating func skipPendingBreak() {
        guard let nextPhase, nextPhase != .focus else { return }
        self.nextPhase = nil
    }

    public mutating func reset() {
        deadline = nil
        pausedRemaining = nil
        nextPhase = nil
        quickDuration = nil
    }

    public mutating func resetCycle() {
        reset()
        phase = .focus
        completedFocusSessions = 0
    }
}
