@testable import CalsynCore
import XCTest

private final class FakeOpener: Opener {
    let status: Int32
    private(set) var calls: [String] = []

    init(status: Int32 = 0) {
        self.status = status
    }

    func open(_ path: String) -> OpenResult {
        calls.append(path)
        return OpenResult(status: status, output: status == 0 ? "" : "The application cannot be opened.")
    }
}

final class ConfigEditorTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("calsyn-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testOpenCreatesMissingFileWithParentFolders() throws {
        let path = root.appendingPathComponent(".config/calsyn/config.yaml").path
        let opener = FakeOpener()

        let code = ConfigEditor.open(path: path, opener: opener)

        XCTAssertEqual(code, 0)
        XCTAssertEqual(try String(contentsOfFile: path, encoding: .utf8), "")
        XCTAssertEqual(opener.calls, [path])
    }

    func testOpenKeepsExistingFile() throws {
        let path = root.appendingPathComponent("config.yaml").path
        try "calendars: []\n".write(toFile: path, atomically: true, encoding: .utf8)
        let opener = FakeOpener()

        let code = ConfigEditor.open(path: path, opener: opener)

        XCTAssertEqual(code, 0)
        XCTAssertEqual(try String(contentsOfFile: path, encoding: .utf8), "calendars: []\n")
        XCTAssertEqual(opener.calls, [path])
    }

    func testOpenFailsWhenOpenerFails() {
        let path = root.appendingPathComponent("config.yaml").path

        let code = ConfigEditor.open(path: path, opener: FakeOpener(status: 1))

        XCTAssertNotEqual(code, 0)
    }

    func testOpenFailsWhenFileCannotBeCreated() throws {
        let blocker = root.appendingPathComponent("calsyn")
        try "not a folder".write(to: blocker, atomically: true, encoding: .utf8)
        let opener = FakeOpener()

        let code = ConfigEditor.open(path: blocker.appendingPathComponent("config.yaml").path, opener: opener)

        XCTAssertNotEqual(code, 0)
        XCTAssertEqual(opener.calls, [])
    }

    func testConfigCommandOpensGivenPath() async throws {
        let path = root.appendingPathComponent("custom/calsyn.yaml").path
        let opener = FakeOpener()

        let code = await CLI.main(["config", "--config", path], opener: opener)

        XCTAssertEqual(code, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: path))
        XCTAssertEqual(opener.calls, [path])
    }
}
