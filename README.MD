# Pomodoro

A small, local-only **macOS menu-bar Pomodoro timer** (macOS 14+). Built with SwiftUI, AppKit, and Swift Package Manager; no account, network service, or third-party dependencies.

## Build and run

Install Xcode and its command-line tools, then run:

```sh
swift test
./scripts/build-app.sh
open build/Pomodoro.app
```

The app appears in the menu bar without a Dock icon. Use **Quit** in its popover to exit. For development, `swift run Pomodoro` also works; the `.app` bundle is the normal way to launch it. The build script ad-hoc signs the app for **local use**; it does not produce a notarized release.

## How it works

- Defaults: 25-minute focus, 5-minute short break, 15-minute long break after four completed focus sessions. Change durations and the long-break interval in **Settings**; preferences are stored locally.
- An optional clock tick plays only during active focus timers. Short and long breaks are silent while counting down. One tick still plays at phase completion.
- When a phase ends, a full-screen reminder asks you to start the next phase. **Nothing starts automatically.** Choose **Start break** or **Start focus** to begin; **Later** closes the reminder while keeping the next phase ready in the menu bar.
- Pause and Reset are available from the popover. **Reset cycle count** returns to focus.
- Time is based on a deadline, so a completed phase is detected when the app resumes after sleep.

## Project layout

- `Sources/PomodoroCore/` — Foundation-only timer state machine.
- `Sources/Pomodoro/` — SwiftUI menu-bar UI, AppKit reminder window, and tick audio.
- `Tests/PomodoroCoreTests/` — timer behavior tests (`swift test`).
- `scripts/build-app.sh` — builds and signs a local `.app` bundle.
- [`AGENT.MD`](AGENT.MD) — development guidance for coding agents and contributors; [`AGENTS.md`](AGENTS.md) is the conventional entry point.

## Known limits

This is an MVP. It does not launch at login, send fallback macOS notifications, sync data, or preserve an in-progress timer across app restarts. A custom full-screen window cannot appear over the macOS lock screen. Full-screen-app and multi-display behavior still needs hands-on testing. The window approach was informed by [MeetingBar's WindowCoordinator](https://github.com/leits/MeetingBar/blob/master/MeetingBar/App/WindowCoordinator.swift); no MeetingBar code is included here.

## License

[MIT](LICENSE) © 2026 Tomas Avé. Contributions are welcome via issues and pull requests; please run `swift test` before submitting changes.
