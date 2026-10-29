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
- An optional clock tick plays only during active focus timers (a bundled recording, `Resources/tick.wav`, with a synthesized fallback). Its volume is adjustable in **Settings** (the slider previews the tick on release) and applies to the completion sound too. Short and long breaks are silent while counting down. One tick still plays at phase completion.
- When a phase ends, a full-screen reminder asks you to start the next phase. **Nothing starts automatically.** Choose **Start break** or **Start focus** to begin; **Later** closes the reminder while keeping the next phase ready in the menu bar.
- Before starting, choose **Focus**, **Short break**, or **Long break** using the session selector. Selection uses the configured duration without changing cycle progress; press **Start** to begin. While running, paused, or awaiting confirmation, use **Reset** first to discard that session before switching. Break completion still waits for explicit focus confirmation.
- Pause and Reset are available from the popover. **Reset cycle count** returns to focus.
- **Quick focus:** when idle in focus, the **Quick** menu starts a one-off 10, 15, 20 minute or custom (1–60) session without changing your configured focus length. Quick sessions don't count toward the long-break cycle and are always followed by a short break; **Skip break** declines a pending break and returns to idle focus.
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
