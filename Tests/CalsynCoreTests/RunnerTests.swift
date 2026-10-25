@testable import CalsynCore
import XCTest

final class RunnerTests: XCTestCase {
    private let work = CalendarInfo(storeID: "work-id", account: "Exchange", title: "Calendar")
    private let home = CalendarInfo(storeID: "home-id", account: "tom@gmail.com", title: "Calendar")
    private let today = Calendar.current.startOfDay(for: Date())
    private var tomorrow: Date {
        (Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today).addingTimeInterval(10 * 3600)
    }
    private var window: DateInterval {
        Reconciler.window(WindowConfig(pastDays: 0, futureDays: 7), now: Date())
    }

    private func config(_ source: CalendarInfo, to destination: CalendarInfo) -> String {
        """
        calendars:
          - id: Exchange/Calendar
            clone_prefix: "[W]"
          - id: tom@gmail.com/Calendar
            clone_prefix: "[H]"
        sync:
          - name: \(source.account)-to-\(destination.account)
            sources:
              - \(source.id)
            destinations:
              - \(destination.id)
        """
    }

    private func event(_ title: String) -> EventContent {
        EventContent(title: title, notes: "", start: tomorrow, end: tomorrow.addingTimeInterval(3600), isAllDay: false)
    }

    private func triggersWriting(_ edited: String, to path: String) -> AsyncStream<Void> {
        AsyncStream(unfolding: {
            guard (try? String(contentsOfFile: path, encoding: .utf8)) != edited,
                  (try? edited.write(toFile: path, atomically: true, encoding: .utf8)) != nil else {
                return nil
            }
            return ()
        })
    }

    func testConfigReloadedAtEveryReconcile() async throws {
        let store = InMemoryCalendarStore(calendars: [work, home])
        try store.create(event("Budget"), in: work)
        try store.create(event("Dinner"), in: home)
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("calsyn-\(UUID().uuidString).yaml").path
        addTeardownBlock { try? FileManager.default.removeItem(atPath: path) }
        try config(work, to: home).write(toFile: path, atomically: true, encoding: .utf8)

        let code = await Runner.run(configPath: path, store: store, triggers: triggersWriting(config(home, to: work), to: path))

        XCTAssertEqual(code, 0)
        XCTAssertEqual(try store.events(in: home, during: window).map(\.content), [event("Dinner"), event("[W]")])
        XCTAssertEqual(try store.events(in: work, during: window).map(\.content), [event("Budget"), event("[H]")])
    }

    func testCleanupOnlyJobsWithCleanup() async throws {
        let store = InMemoryCalendarStore(calendars: [work, home])
        try store.create(event("[W]"), in: home)
        try store.create(event("[H]"), in: work)
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("calsyn-\(UUID().uuidString).yaml").path
        addTeardownBlock { try? FileManager.default.removeItem(atPath: path) }
        try """
        \(config(work, to: home))
            cleanup: true
          - name: home-to-work
            sources:
              - \(home.id)
            destinations:
              - \(work.id)
        """.write(toFile: path, atomically: true, encoding: .utf8)

        let code = await Runner.cleanup(configPath: path, store: store)

        XCTAssertEqual(code, 0)
        XCTAssertEqual(try store.events(in: home, during: window).map(\.content), [])
        XCTAssertEqual(try store.events(in: work, during: window).map(\.content), [event("[H]")])
    }
}
