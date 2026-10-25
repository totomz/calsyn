@testable import CalsynCore
import XCTest

final class ConfigLoaderTests: XCTestCase {
    private func fixture(_ name: String) throws -> String {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures/\(name)", withExtension: "yaml"))
        return url.path
    }

    private func loadError(_ name: String) throws -> ConfigError? {
        let path = try fixture(name)
        do {
            _ = try ConfigLoader.load(path: path)
            return nil
        } catch {
            return error
        }
    }

    func testValidConfig() throws {
        let config = try ConfigLoader.load(path: try fixture("valid"))
        XCTAssertEqual(config.calendars, [
            CalendarConfig(id: "tom@gmail.com/Calendar", clonePrefix: "[tom]"),
            CalendarConfig(id: "Exchange/Calendar", clonePrefix: "[W]"),
        ])
        XCTAssertEqual(config.sync, [
            SyncJob(
                name: "gmail -> work",
                sources: ["tom@gmail.com/Calendar"],
                destinations: ["Exchange/Calendar"],
                details: SyncDetails(title: false, description: false),
                cleanup: false
            ),
        ])
    }

    func testCleanupFlag() throws {
        let config = try ConfigLoader.parse("""
        calendars:
          - id: Exchange/Calendar
            clone_prefix: "[W]"
        sync:
          - name: with-cleanup
            sources: [Exchange/Calendar]
            destinations: [Exchange/Calendar]
            cleanup: true
          - name: without-cleanup
            sources: [Exchange/Calendar]
            destinations: [Exchange/Calendar]
        """)
        XCTAssertEqual(config.sync.map(\.cleanup), [true, false])
    }

    func testDetailsDefaultToFalse() throws {
        let config = try ConfigLoader.load(path: try fixture("valid-partial-details"))
        XCTAssertEqual(config.sync.first?.details, SyncDetails(title: true, description: false))
    }

    func testMissingClonePrefix() throws {
        XCTAssertEqual(try loadError("missing-clone-prefix"), .missingField(field: "calendars[1].clone_prefix"))
    }

    func testMissingDestinations() throws {
        XCTAssertEqual(try loadError("missing-destinations"), .missingField(field: "sync[0].destinations"))
    }

    func testUnknownDestination() throws {
        XCTAssertEqual(
            try loadError("unknown-destination"),
            .unknownCalendar(field: "sync[0].destinations[1]", id: "foo")
        )
    }

    func testUnknownSource() throws {
        XCTAssertEqual(try loadError("unknown-source"), .unknownCalendar(field: "sync[0].sources[0]", id: "bar"))
    }
}
