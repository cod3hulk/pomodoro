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

    public init(settings: TimerSettings = .init()) { self.settings = settings }
    public var isRunning: Bool { deadline != nil }

    public func remaining(at now: Date = .now) -> TimeInterval {
        if let deadline { return max(0, deadline.timeIntervalSince(now)) }
        return pausedRemaining ?? settings.duration(for: phase)
    }

    public mutating func start(at now: Date = .now) {
        guard deadline == nil, nextPhase == nil else { return }
        deadline = now.addingTimeInterval(pausedRemaining ?? settings.duration(for: phase))
        pausedRemaining = nil
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
            completedFocusSessions += 1
            nextPhase = completedFocusSessions % settings.longBreakEvery == 0 ? .longBreak : .shortBreak
        } else {
            nextPhase = .focus
        }
        return nextPhase
    }

    public mutating func confirmNextPhase(at now: Date = .now) {
        guard let nextPhase else { return }
        phase = nextPhase
        self.nextPhase = nil
        pausedRemaining = nil
        start(at: now)
    }

    public mutating func reset() {
        deadline = nil
        pausedRemaining = nil
        nextPhase = nil
    }

    public mutating func resetCycle() {
        reset()
        phase = .focus
        completedFocusSessions = 0
    }
}
