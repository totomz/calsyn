@testable import CalsynCore
import XCTest

final class ReconcilerTests: XCTestCase {
    private let work = CalendarInfo(storeID: "work-id", account: "Exchange", title: "Calendar")
    private let home = CalendarInfo(storeID: "home-id", account: "tom@gmail.com", title: "Calendar")
    private let calendars = [
        CalendarConfig(id: "Exchange/Calendar", clonePrefix: "[W]"),
        CalendarConfig(id: "tom@gmail.com/Calendar", clonePrefix: "[H]"),
    ]
    private let today = Date(timeIntervalSince1970: 1_792_627_200)
    private var window: DateInterval {
        DateInterval(start: today, duration: 7 * 24 * 3600)
    }
    private var store = InMemoryCalendarStore(calendars: [])

    override func setUp() {
        store = InMemoryCalendarStore(calendars: [work, home])
    }

    private func syncJob(
        _ source: CalendarInfo,
        _ destination: CalendarInfo,
        title: Bool = false,
        description: Bool = false
    ) -> SyncJob {
        SyncJob(
            name: "\(source.account)-to-\(destination.account)",
            sources: [source.id],
            destinations: [destination.id],
            details: SyncDetails(title: title, description: description)
        )
    }

    private func event(_ title: String, day: Int, at hour: Int = 10, notes: String = "") -> EventContent {
        let start = today.addingTimeInterval(TimeInterval((24 * day + hour) * 3600))
        return EventContent(title: title, notes: notes, start: start, end: start.addingTimeInterval(3600), isAllDay: false)
    }

    private func tomorrow(_ title: String, at hour: Int, notes: String = "") -> EventContent {
        event(title, day: 1, at: hour, notes: notes)
    }

    private func reconcile(_ job: SyncJob) throws -> JobResult {
        try Reconciler.reconcile(job: job, calendars: calendars, store: store, window: window)
    }

    private func contents(_ calendar: CalendarInfo) throws -> [EventContent] {
        try store.events(in: calendar, during: window).map(\.content)
    }

    private func loadConfig(_ window: String) throws -> Config {
        try ConfigLoader.parse("""
        calendars:
          - id: Exchange/Calendar
            clone_prefix: "[W]"
          - id: tom@gmail.com/Calendar
            clone_prefix: "[H]"
        sync:
          - name: work-to-home
            sources:
              - Exchange/Calendar
            destinations:
              - tom@gmail.com/Calendar
        \(window)
        """)
    }

    private func reconcile(_ config: Config) throws -> JobResult {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let window = Reconciler.window(config.window, now: today.addingTimeInterval(15 * 3600), calendar: utc)
        let job = try XCTUnwrap(config.sync.first)
        return try Reconciler.reconcile(job: job, calendars: config.calendars, store: store, window: window)
    }

    private func allContents(_ calendar: CalendarInfo) throws -> [EventContent] {
        let everything = DateInterval(start: today.addingTimeInterval(-60 * 24 * 3600), duration: 120 * 24 * 3600)
        return try store.events(in: calendar, during: everything).map(\.content)
    }

    private func replaceSource(with event: EventContent) throws {
        let source = try XCTUnwrap(store.events(in: work, during: window).first)
        try store.delete(source)
        try store.create(event, in: work)
    }

    func testFirstClone() throws {
        try store.create(tomorrow("Budget", at: 10, notes: "Q4 numbers"), in: work)

        XCTAssertEqual(try reconcile(syncJob(work, home)), JobResult(created: 1, deleted: 0))
        XCTAssertEqual(try contents(home), [tomorrow("[W]", at: 10)])
    }

    func testTitleAndDescriptionCloned() throws {
        try store.create(tomorrow("Budget", at: 10, notes: "Q4 numbers"), in: work)

        _ = try reconcile(syncJob(work, home, title: true, description: true))
        XCTAssertEqual(try contents(home), [tomorrow("[W] Budget", at: 10, notes: "Q4 numbers")])
    }

    func testSourceMoved() throws {
        let job = syncJob(work, home)
        try store.create(tomorrow("Budget", at: 10), in: work)
        _ = try reconcile(job)
        try replaceSource(with: tomorrow("Budget", at: 14))

        XCTAssertEqual(try reconcile(job), JobResult(created: 1, deleted: 1))
        XCTAssertEqual(try contents(home), [tomorrow("[W]", at: 14)])
    }

    func testClonedTitleChanged() throws {
        let job = syncJob(work, home, title: true)
        try store.create(tomorrow("Budget", at: 10), in: work)
        _ = try reconcile(job)
        try replaceSource(with: tomorrow("Budget review", at: 10))

        XCTAssertEqual(try reconcile(job), JobResult(created: 1, deleted: 1))
        XCTAssertEqual(try contents(home), [tomorrow("[W] Budget review", at: 10)])
    }

    func testSourceDeleted() throws {
        let job = syncJob(work, home)
        try store.create(tomorrow("Budget", at: 10), in: work)
        _ = try reconcile(job)
        try store.delete(try XCTUnwrap(store.events(in: work, during: window).first))

        XCTAssertEqual(try reconcile(job), JobResult(created: 0, deleted: 1))
        XCTAssertEqual(try contents(home), [])
    }

    func testBidirectionalJobsConverge() throws {
        let jobs = [syncJob(work, home), syncJob(home, work)]
        try store.create(tomorrow("Budget", at: 10), in: work)
        try store.create(tomorrow("Dinner", at: 19), in: home)
        for job in jobs {
            _ = try reconcile(job)
        }

        for job in jobs {
            XCTAssertEqual(try reconcile(job), JobResult(created: 0, deleted: 0))
        }
    }

    func testLegacyClones() throws {
        try store.create(tomorrow("Budget", at: 10), in: work)
        try store.create(tomorrow("[W]", at: 10), in: home)
        try store.create(tomorrow("[W]", at: 16), in: home)

        XCTAssertEqual(try reconcile(syncJob(work, home)), JobResult(created: 0, deleted: 1))
        XCTAssertEqual(try contents(home), [tomorrow("[W]", at: 10)])
    }

    func testDefaultWindow() throws {
        for day in [-1, 0, 6, 7] {
            try store.create(event("Budget", day: day), in: work)
        }

        _ = try reconcile(try loadConfig(""))
        XCTAssertEqual(try allContents(home), [event("[W]", day: 0), event("[W]", day: 6)])
    }

    func testWindowOverride() throws {
        for day in [-3, -2, 13, 14] {
            try store.create(event("Budget", day: day), in: work)
        }

        _ = try reconcile(try loadConfig("window:\n  past_days: 2\n  future_days: 14"))
        XCTAssertEqual(try allContents(home), [event("[W]", day: -2), event("[W]", day: 13)])
    }

    func testClonesOutsideWindowLeftAlone() throws {
        try store.create(event("[W]", day: 30), in: home)

        XCTAssertEqual(try reconcile(try loadConfig("")), JobResult(created: 0, deleted: 0))
        XCTAssertEqual(try allContents(home), [event("[W]", day: 30)])
    }
}
