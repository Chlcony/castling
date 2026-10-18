// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Chlcony

import Foundation

// Runs the patch's own tests outside upstream's suite, so the patch never
// has to register anything in upstream's build.sh or Tests/. TestSuite keeps
// the shape of upstream's, which the test file is written against.
final class TestSuite {
    private(set) var checks = 0
    private(set) var failures: [String] = []

    func expect(_ condition: Bool, _ message: @autoclosure () -> String,
                file: StaticString = #filePath, line: UInt = #line) {
        checks += 1
        if !condition { failures.append("\(file):\(line): \(message())") }
    }
}

let suite = TestSuite()
DisplayArrangementTests.run(suite)
#if CASTLING_UPDATE_HOOK
CastlingUpdateTests.run(suite)
#endif
if suite.checks == 0 { suite.expect(false, "no assertions ran") }
if suite.failures.isEmpty {
    print("PATCH TESTS OK (\(suite.checks) checks)")
    exit(0)
}
print("PATCH TESTS FAILED (\(suite.failures.count) of \(suite.checks)):")
suite.failures.forEach { print("  - \($0)") }
exit(1)
