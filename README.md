# Pomodoro

A small, local-only macOS menu-bar Pomodoro app (macOS 14+). Built with SwiftUI, AppKit and Swift Package Manager; no dependencies or account.

## Run

Requires Xcode and its command-line tools:

```sh
swift test
./scripts/build-app.sh
open build/Pomodoro.app
```

The app appears in the menu bar (no Dock icon). Use **Quit** in its menu to exit. For development, `swift run Pomodoro` also works, but use the app bundle for normal use.

## Behavior

- Defaults: 25-minute focus, 5-minute short break, 15-minute long break after four completed focus sessions. Durations and cycle interval are editable in Settings and saved locally.
- A clock-like tick plays while a timer runs; Settings can mute it. The end of a phase plays one tick and opens a full-screen reminder on the current screen.
- **Start break** / **Start focus** explicitly starts the next phase. **Later** closes the reminder but leaves the next phase waiting in the menu bar.
- Pause and Reset are available from the menu bar. Reset cycle count returns to focus.
- Time uses an absolute deadline; if the Mac sleeps past the deadline, completion is detected when the app next runs.

## Current limits

This is an MVP, not a signed/notarized release. It does not start automatically on login, send fallback macOS notifications, sync data, or persist an in-progress timer across app restarts. A custom full-screen window cannot appear over the macOS lock screen; multi-display and full-screen-app behavior still need hands-on testing. Its window strategy was informed by [MeetingBar's WindowCoordinator](https://github.com/leits/MeetingBar/blob/master/MeetingBar/App/WindowCoordinator.swift).
