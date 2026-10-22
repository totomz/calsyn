@testable import CalsynCore
import XCTest

final class LogFormatterTests: XCTestCase {
    private let time = Date(timeIntervalSince1970: 0)

    private func dropTime(_ line: String) -> String {
        String(line.drop { $0 != " " }.dropFirst())
    }

    func testInfoLine() {
        let line = LogFormatter.line(
            level: .info,
            msg: "settings loaded",
            fields: ["calendars": 2, "sync_jobs": 1],
            time: time
        )
        XCTAssertTrue(line.hasPrefix("time="))
        XCTAssertEqual(dropTime(line), "level=INFO msg=\"settings loaded\" calendars=2 sync_jobs=1")
    }

    func testErrorLine() {
        let line = LogFormatter.line(
            level: .error,
            msg: "missing required field",
            fields: ["field": "calendars[1].clone_prefix"],
            time: time
        )
        XCTAssertEqual(dropTime(line), "level=ERROR msg=\"missing required field\" field=calendars[1].clone_prefix")
    }

    func testQuoting() {
        XCTAssertEqual(LogFormatter.quote("a b"), "\"a b\"")
        XCTAssertEqual(LogFormatter.quote("say \"hi\""), "\"say \\\"hi\\\"\"")
    }
}
