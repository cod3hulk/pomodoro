#!/usr/bin/env python3
"""Compile/run isolated TimerStore smoke checks without launching Pomodoro."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="pomodoro-store-") as directory:
    directory = Path(directory)
    subprocess.run([
        "swiftc", "-emit-library", "-emit-module", "-module-name", "PomodoroCore",
        str(root / "Sources/PomodoroCore/TimerEngine.swift"),
        "-o", str(directory / "libPomodoroCore.dylib"),
        "-emit-module-path", str(directory / "PomodoroCore.swiftmodule"),
    ], check=True)
    executable = directory / "store-smoke-tests"
    subprocess.run([
        "swiftc", "-I", str(directory), "-L", str(directory), "-lPomodoroCore",
        "-Xlinker", "-rpath", "-Xlinker", str(directory),
        str(root / "Sources/Pomodoro/TimerStore.swift"),
        str(root / "Sources/Pomodoro/TickSound.swift"),
        str(root / "Sources/Pomodoro/TimerView.swift"),
        str(root / "Tests/SmokeTests/TimerStoreSmokeTests.swift"),
        "-o", str(executable),
    ], check=True)
    subprocess.run([str(executable)], check=True)
