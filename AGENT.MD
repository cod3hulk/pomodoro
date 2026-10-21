# Agent guide — Pomodoro

This is a native macOS menu-bar Pomodoro app. Keep it small, local-only, and dependency-free unless a change clearly requires otherwise.

## Build and test

- Requirements: macOS 14+, Xcode and Swift 6 toolchain.
- `swift test` runs the timer-engine XCTest suite.
- `./scripts/build-app.sh` creates and ad-hoc signs `build/Pomodoro.app`.
- `open build/Pomodoro.app` launches the menu-bar app; use **Quit** in the popover to stop it.
- Never commit `.build/` or `build/`. The generated app is for local use, not a notarized distribution.

## Structure

- `Sources/PomodoroCore/TimerEngine.swift`: Foundation-only state machine and deadline-based timekeeping. Keep UI and audio dependencies out of this target.
- `Tests/PomodoroCoreTests/`: phase transitions, long-break cadence, pause/resume, sleep/wake, and explicit confirmation tests.
- `Sources/Pomodoro/`: SwiftUI `MenuBarExtra`, settings/presentation, AppKit full-screen window, and synthesized tick sound.
- `scripts/build-app.sh`: `.app` bundle assembly and local signing; `LSUIElement` hides the Dock icon.

## Behavior contracts

- A completed phase must leave `nextPhase` pending. Closing the overlay with **Later** must not start the next timer; only explicit confirmation does.
- Long breaks follow the configured number of completed focus sessions. A paused session does not increment the count.
- Compute time remaining from an absolute deadline, not from the number of timer callbacks. Reconcile completion after the machine wakes.
- Keep the pending action reachable from the menu-bar popover even if the full-screen window is dismissed.
- Preferences remain local in `UserDefaults`. Avoid changing the duration of an already running/paused phase when settings change.
- The overlay uses a borderless `NSWindow` on the active screen. Test visibility and behavior manually with full-screen apps, multiple displays, and sleep/wake; unit tests and a successful build alone do not prove window placement.

## Working agreement

Write a failing timer-engine test before changing behavior, then run `swift test` and build the app. State clearly when a UI or multi-display path has not been manually tested. Do not add analytics, network access, or automatic phase transitions without an explicit product decision.
