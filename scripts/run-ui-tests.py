#!/usr/bin/env python3
"""Exercise real SwiftUI/AppKit layout without touching the installed app.

The control guard excludes the known hot sizing path. This is not a deterministic
reproduction of the original long-lived high-CPU condition.
"""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="pomodoro-ui-") as directory:
    directory = Path(directory)
    subprocess.run([
        "swiftc", "-emit-library", "-emit-module", "-module-name", "PomodoroCore",
        str(root / "Sources/PomodoroCore/TimerEngine.swift"),
        "-o", str(directory / "libPomodoroCore.dylib"),
        "-emit-module-path", str(directory / "PomodoroCore.swiftmodule"),
    ], check=True, timeout=90)
    executable = directory / "ui-smoke-tests"
    subprocess.run([
        "swiftc", "-I", str(directory), "-L", str(directory), "-lPomodoroCore",
        "-Xlinker", "-rpath", "-Xlinker", str(directory),
        str(root / "Sources/Pomodoro/TimerStore.swift"),
        str(root / "Sources/Pomodoro/TickSound.swift"),
        str(root / "Sources/Pomodoro/TimerView.swift"),
        str(root / "Tests/SmokeTests/TimerViewSmokeTests.swift"),
        "-o", str(executable),
    ], check=True, timeout=90)
    subprocess.run([str(executable)], check=True, timeout=15)
