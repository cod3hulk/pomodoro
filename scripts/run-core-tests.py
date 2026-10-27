#!/usr/bin/env python3
"""Run Tests/PomodoroCoreTests without Xcode.

`swift test` needs XCTest, which ships with Xcode but not with the Command Line
Tools. This compiles the real test file against PomodoroCore with a tiny XCTest
shim. Prefer `swift test` whenever Xcode is available.
"""
from pathlib import Path
import re
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
engine = root / "Sources/PomodoroCore/TimerEngine.swift"
test_file = root / "Tests/PomodoroCoreTests/TimerEngineTests.swift"

SHIM = '''import Foundation
nonisolated(unsafe) var shimFailures = 0
nonisolated(unsafe) var shimAssertions = 0
class XCTestCase { required init() {} }
func shimCheck(_ ok: Bool, _ message: @autoclosure () -> String, _ line: UInt) {
    shimAssertions += 1
    if !ok { shimFailures += 1; print("  line \\(line): \\(message())") }
}
func XCTAssertEqual<T: Equatable>(_ a: @autoclosure () -> T, _ b: @autoclosure () -> T, line: UInt = #line) {
    let (x, y) = (a(), b()); shimCheck(x == y, "\\(x) != \\(y)", line)
}
func XCTAssertTrue(_ a: @autoclosure () -> Bool, line: UInt = #line) { shimCheck(a(), "expected true", line) }
func XCTAssertFalse(_ a: @autoclosure () -> Bool, line: UInt = #line) { shimCheck(!a(), "expected false", line) }
func XCTAssertNil<T>(_ a: @autoclosure () -> T?, line: UInt = #line) { shimCheck(a() == nil, "expected nil", line) }
'''

source = test_file.read_text()
source = re.sub(r"^import XCTest\s*$|^@testable import PomodoroCore\s*$", "", source, flags=re.M)
source = "import Foundation\n" + source
classes = re.findall(r"final class (\w+): XCTestCase", source)
names = re.findall(r"func (test\w+)\(\)", source)
assert classes and names, "no tests found"

runner = "import Foundation\nvar failedTests = 0\n"
for cls in classes:
    for name in names:
        runner += (f'do {{ let before = shimFailures; {cls}().{name}(); '
                   f'let ok = shimFailures == before; if !ok {{ failedTests += 1 }}; '
                   f'print("\\(ok ? "PASS" : "FAIL") {cls}.{name}") }}\n')
runner += ('print("\\(shimAssertions) assertions, \\(failedTests) failing tests")\n'
           'exit(failedTests == 0 ? 0 : 1)\n')

with tempfile.TemporaryDirectory(prefix="pomodoro-core-") as d:
    d = Path(d)
    (d / "Shim.swift").write_text(SHIM)
    (d / "Tests.swift").write_text(source)
    (d / "main.swift").write_text(runner)
    binary = d / "core-tests"
    build = subprocess.run(
        ["swiftc", "-swift-version", "5", str(engine), str(d / "Shim.swift"),
         str(d / "Tests.swift"), str(d / "main.swift"), "-o", str(binary)])
    if build.returncode != 0:
        sys.exit(build.returncode)
    sys.exit(subprocess.run([str(binary)]).returncode)
