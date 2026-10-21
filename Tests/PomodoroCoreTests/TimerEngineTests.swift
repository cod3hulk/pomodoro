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
}
