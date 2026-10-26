#!/usr/bin/env python3
"""Exercise the app's countdown-tick condition without requiring XCTest."""
from pathlib import Path
import re
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
source = (root / "Sources/Pomodoro/TimerStore.swift").read_text()
match = re.search(r"if let oldSecond,\s*(.*?)\s*\{ sound\.play\(\) \}", source, re.S)
assert match, "Countdown sound condition not found"
condition = match.group(1).replace(",", " && ")
program = '''import Foundation
var failures = 0
var checks = 0
for phase in [Phase.focus, .shortBreak, .longBreak] {
    for enabled in [true, false] {
        for (oldSecond, newSecond) in [(10, 9), (10, 10), (10, 8), (1, 0)] {
            var engine = TimerEngine(settings: .init(focus: 60, shortBreak: 60, longBreak: 60, longBreakEvery: phase == .longBreak ? 1 : 4))
            let start = Date(timeIntervalSince1970: 0)
            engine.start(at: start)
            if phase != .focus {
                engine.advance(to: start.addingTimeInterval(60))
                engine.confirmNextPhase(at: start.addingTimeInterval(60))
            }
            let tickEnabled = enabled
            let actual = CONDITION
            let expected = phase == .focus && enabled && oldSecond - newSecond == 1 && newSecond > 0
            checks += 1
            if actual != expected {
                print("FAIL: \\(phase), enabled=\\(enabled), \\(oldSecond)->\\(newSecond): tick=\\(actual), expected=\\(expected)")
                failures += 1
            }
        }
    }
}
print("\\(checks) countdown tick checks; \\(failures) failures")
exit(failures == 0 ? 0 : 1)
'''.replace("CONDITION", condition)
with tempfile.TemporaryDirectory(prefix="pomodoro-tick-") as directory:
    main = Path(directory) / "main.swift"
    main.write_text(program)
    binary = Path(directory) / "tick-tests"
    subprocess.run(["swiftc", str(root / "Sources/PomodoroCore/TimerEngine.swift"), str(main), "-o", str(binary)], check=True)
    subprocess.run([str(binary)], check=True)
