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
            CalendarConfig(name: "@gmail", account: "tom@gmail.com", title: "Calendar", clonePrefix: "[tom]"),
            CalendarConfig(name: "work", account: "Exchange", title: "Calendar", clonePrefix: "[W]"),
        ])
        XCTAssertEqual(config.sync, [
            SyncJob(
                name: "gmail -> work",
                source: "@gmail",
                destinations: ["work"],
                details: SyncDetails(title: false, description: false)
            ),
        ])
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
            .unknownCalendar(field: "sync[0].destinations[1]", name: "foo")
        )
    }

    func testUnknownSource() throws {
        XCTAssertEqual(try loadError("unknown-source"), .unknownCalendar(field: "sync[0].source", name: "bar"))
    }
}
