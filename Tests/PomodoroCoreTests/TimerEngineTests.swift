import XCTest
@testable import PomodoroCore

final class TimerEngineTests: XCTestCase {
    func testFocusCompletionWaitsForConfirmation() {
        var timer = TimerEngine(settings: .init(focus: 25, shortBreak: 5, longBreak: 15, longBreakEvery: 4))
        let start = Date(timeIntervalSince1970: 1_000)
        timer.start(at: start)
        timer.advance(to: start.addingTimeInterval(25))
        XCTAssertEqual(timer.phase, .focus)
        XCTAssertEqual(timer.nextPhase, .shortBreak)
        XCTAssertFalse(timer.isRunning)
        XCTAssertEqual(timer.completedFocusSessions, 1)
        timer.advance(to: start.addingTimeInterval(99))
        XCTAssertEqual(timer.nextPhase, .shortBreak)
        timer.confirmNextPhase(at: start.addingTimeInterval(100))
        XCTAssertEqual(timer.phase, .shortBreak)
        XCTAssertTrue(timer.isRunning)
    }

    func testLongBreakAfterConfiguredFocusSessions() {
        var timer = TimerEngine(settings: .init(focus: 10, shortBreak: 5, longBreak: 15, longBreakEvery: 2))
        let start = Date(timeIntervalSince1970: 1_000)
        timer.start(at: start)
        timer.advance(to: start.addingTimeInterval(10))
        timer.confirmNextPhase(at: start.addingTimeInterval(10))
        timer.advance(to: start.addingTimeInterval(15))
        XCTAssertEqual(timer.nextPhase, .focus)
        timer.confirmNextPhase(at: start.addingTimeInterval(15))
        timer.advance(to: start.addingTimeInterval(25))
        XCTAssertEqual(timer.nextPhase, .longBreak)
    }

    func testPauseResumeAndSleepUseDeadline() {
        var timer = TimerEngine(settings: .init(focus: 60, shortBreak: 5, longBreak: 15, longBreakEvery: 4))
        let start = Date(timeIntervalSince1970: 1_000)
        timer.start(at: start)
        timer.pause(at: start.addingTimeInterval(20))
        XCTAssertEqual(timer.remaining(at: start.addingTimeInterval(100)), 40)
        timer.start(at: start.addingTimeInterval(100))
        timer.advance(to: start.addingTimeInterval(140))
        XCTAssertEqual(timer.nextPhase, .shortBreak)
    }

    func testResetDoesNotChangeCompletedCountByDefault() {
        var timer = TimerEngine(settings: .init(focus: 1, shortBreak: 1, longBreak: 1, longBreakEvery: 4))
        let now = Date(timeIntervalSince1970: 1_000)
        timer.start(at: now)
        timer.advance(to: now.addingTimeInterval(1))
        timer.reset()
        XCTAssertEqual(timer.completedFocusSessions, 1)
        XCTAssertEqual(timer.phase, .focus)
        XCTAssertNil(timer.nextPhase)
        XCTAssertFalse(timer.isRunning)
    }

    func testSelectPhasePreparesBreakWithoutStartingOrCountingFocus() {
        var timer = TimerEngine(settings: .init(focus: 100, shortBreak: 20, longBreak: 30))
        let start = Date(timeIntervalSince1970: 1_000)
        for phase in [Phase.shortBreak, .longBreak, .focus] {
            timer.selectPhase(phase)
            XCTAssertEqual(timer.phase, phase)
            XCTAssertFalse(timer.isRunning)
            XCTAssertNil(timer.nextPhase)
            XCTAssertEqual(timer.remaining(at: start), timer.settings.duration(for: phase))
            XCTAssertEqual(timer.completedFocusSessions, 0)
        }
        timer.selectPhase(.shortBreak)
        timer.start(at: start)
        timer.advance(to: start.addingTimeInterval(20))
        XCTAssertEqual(timer.nextPhase, .focus)
        XCTAssertEqual(timer.completedFocusSessions, 0)
    }

    func testPhaseSelectionProtectsRunningPausedAndPendingSessions() {
        let start = Date(timeIntervalSince1970: 1_000)
        for quick in [false, true] {
            var timer = makeTimer()
            if quick { timer.startFocus(duration: 40, at: start) }
            else { timer.start(at: start) }
            XCTAssertFalse(timer.isIdle)
            timer.selectPhase(.longBreak)
            XCTAssertEqual(timer.phase, .focus)
            timer.pause(at: start) // Even a paused timer with its full duration isn't idle.
            XCTAssertFalse(timer.isIdle)
            timer.selectPhase(.shortBreak)
            XCTAssertEqual(timer.phase, .focus)
            XCTAssertEqual(timer.isQuickSession, quick)
            timer.start(at: start)
            timer.advance(to: start.addingTimeInterval(100))
            XCTAssertFalse(timer.isIdle)
            timer.selectPhase(.longBreak)
            XCTAssertEqual(timer.nextPhase, .shortBreak)
            timer.reset()
            XCTAssertTrue(timer.isIdle)
            timer.selectPhase(.longBreak)
            XCTAssertEqual(timer.phase, .longBreak)
            XCTAssertFalse(timer.isQuickSession)
            XCTAssertEqual(timer.completedFocusSessions, quick ? 0 : 1)
        }
    }

    // MARK: Quick focus

    private func makeTimer() -> TimerEngine {
        TimerEngine(settings: .init(focus: 100, shortBreak: 20, longBreak: 30, longBreakEvery: 2))
    }

    func testQuickFocusUsesOverrideAndLeavesConfiguredFocusUnchanged() {
        var timer = makeTimer()
        let start = Date(timeIntervalSince1970: 1_000)
        timer.startFocus(duration: 40, at: start)
        XCTAssertTrue(timer.isRunning)
        XCTAssertTrue(timer.isQuickSession)
        XCTAssertEqual(timer.remaining(at: start), 40)
        XCTAssertEqual(timer.settings.focus, 100)
        timer.advance(to: start.addingTimeInterval(40))
        XCTAssertFalse(timer.isRunning)
        XCTAssertFalse(timer.isQuickSession)
        XCTAssertEqual(timer.remaining(at: start.addingTimeInterval(41)), 100)
    }

    func testQuickFocusDoesNotCountTowardLongBreakAndAlwaysGivesShortBreak() {
        var timer = makeTimer()
        let start = Date(timeIntervalSince1970: 1_000)
        timer.startFocus(duration: 10, at: start)
        timer.advance(to: start.addingTimeInterval(10))
        XCTAssertEqual(timer.completedFocusSessions, 0)
        XCTAssertEqual(timer.nextPhase, .shortBreak)
        // Two quick sessions in a row (break skipped) must not earn the long break.
        timer.skipPendingBreak()
        timer.startFocus(duration: 10, at: start.addingTimeInterval(11))
        timer.advance(to: start.addingTimeInterval(21))
        XCTAssertEqual(timer.completedFocusSessions, 0)
        XCTAssertEqual(timer.nextPhase, .shortBreak)
    }

    func testFullSessionAfterQuickSessionCountsNormally() {
        var timer = makeTimer()
        let start = Date(timeIntervalSince1970: 1_000)
        timer.startFocus(duration: 10, at: start)
        timer.advance(to: start.addingTimeInterval(10))
        timer.confirmNextPhase(at: start.addingTimeInterval(10))
        timer.advance(to: start.addingTimeInterval(30))
        timer.confirmNextPhase(at: start.addingTimeInterval(30))
        XCTAssertEqual(timer.phase, .focus)
        XCTAssertFalse(timer.isQuickSession)
        timer.advance(to: start.addingTimeInterval(130))
        XCTAssertEqual(timer.completedFocusSessions, 1)
    }

    func testQuickFocusSurvivesPauseAndResume() {
        var timer = makeTimer()
        let start = Date(timeIntervalSince1970: 1_000)
        timer.startFocus(duration: 40, at: start)
        timer.pause(at: start.addingTimeInterval(15))
        XCTAssertTrue(timer.isQuickSession)
        XCTAssertEqual(timer.remaining(at: start.addingTimeInterval(500)), 25)
        timer.start(at: start.addingTimeInterval(500))
        timer.advance(to: start.addingTimeInterval(525))
        XCTAssertEqual(timer.nextPhase, .shortBreak)
        XCTAssertEqual(timer.completedFocusSessions, 0)
    }

    func testResetClearsQuickSession() {
        var timer = makeTimer()
        let start = Date(timeIntervalSince1970: 1_000)
        timer.startFocus(duration: 40, at: start)
        timer.pause(at: start.addingTimeInterval(5))
        timer.reset()
        XCTAssertFalse(timer.isQuickSession)
        XCTAssertEqual(timer.remaining(at: start.addingTimeInterval(6)), 100)
    }

    func testQuickFocusIsRejectedWhenNotIdleInFocus() {
        let start = Date(timeIntervalSince1970: 1_000)

        var running = makeTimer()
        running.start(at: start)
        running.startFocus(duration: 10, at: start)
        XCTAssertFalse(running.isQuickSession)
        XCTAssertEqual(running.remaining(at: start), 100)

        var paused = makeTimer()
        paused.start(at: start)
        paused.pause(at: start.addingTimeInterval(10))
        paused.startFocus(duration: 10, at: start.addingTimeInterval(10))
        XCTAssertFalse(paused.isQuickSession)
        XCTAssertFalse(paused.isRunning)

        var pending = makeTimer()
        pending.start(at: start)
        pending.advance(to: start.addingTimeInterval(100))
        pending.startFocus(duration: 10, at: start.addingTimeInterval(101))
        XCTAssertFalse(pending.isQuickSession)
        XCTAssertFalse(pending.isRunning)

        var inBreak = makeTimer()
        inBreak.start(at: start)
        inBreak.advance(to: start.addingTimeInterval(100))
        inBreak.confirmNextPhase(at: start.addingTimeInterval(100))
        inBreak.startFocus(duration: 10, at: start.addingTimeInterval(101))
        XCTAssertFalse(inBreak.isQuickSession)
        XCTAssertEqual(inBreak.phase, .shortBreak)
    }

    func testQuickFocusRejectsNonPositiveDuration() {
        var timer = makeTimer()
        timer.startFocus(duration: 0, at: Date(timeIntervalSince1970: 1_000))
        XCTAssertFalse(timer.isRunning)
        XCTAssertFalse(timer.isQuickSession)
    }

    // MARK: Skip break

    func testSkipPendingBreakReturnsToIdleFocusWithoutStartingTimer() {
        var timer = makeTimer()
        let start = Date(timeIntervalSince1970: 1_000)
        timer.startFocus(duration: 10, at: start)
        timer.advance(to: start.addingTimeInterval(10))
        XCTAssertEqual(timer.nextPhase, .shortBreak)
        timer.skipPendingBreak()
        XCTAssertNil(timer.nextPhase)
        XCTAssertEqual(timer.phase, .focus)
        XCTAssertFalse(timer.isRunning)
        XCTAssertEqual(timer.remaining(at: start.addingTimeInterval(11)), 100)
    }

    func testSkipPendingBreakIgnoresPendingFocus() {
        var timer = makeTimer()
        let start = Date(timeIntervalSince1970: 1_000)
        timer.start(at: start)
        timer.advance(to: start.addingTimeInterval(100))
        timer.confirmNextPhase(at: start.addingTimeInterval(100))
        timer.advance(to: start.addingTimeInterval(120))
        XCTAssertEqual(timer.nextPhase, .focus)
        timer.skipPendingBreak()
        XCTAssertEqual(timer.nextPhase, .focus)
    }
}
