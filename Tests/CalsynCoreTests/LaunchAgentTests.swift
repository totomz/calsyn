@testable import CalsynCore
import XCTest

private final class FakeLaunchctl: Launchctl {
    var loaded: Bool
    var failing: String?
    private(set) var calls: [[String]] = []

    init(loaded: Bool = false, failing: String? = nil) {
        self.loaded = loaded
        self.failing = failing
    }

    func run(_ arguments: [String]) -> LaunchctlResult {
        calls.append(arguments)
        let command = arguments.first
        if command == failing {
            return LaunchctlResult(status: 5, output: "5: Input/output error")
        }
        switch command {
        case "print":
            return LaunchctlResult(status: loaded ? 0 : 113, output: "")
        case "bootstrap":
            loaded = true
        case "bootout":
            loaded = false
        default:
            break
        }
        return LaunchctlResult(status: 0, output: "")
    }
}

final class LaunchAgentTests: XCTestCase {
    private var home: URL!
    private var paths: LaunchAgentPaths!
    private var executable: URL!

    override func setUpWithError() throws {
        home = FileManager.default.temporaryDirectory.appendingPathComponent("calsyn-\(UUID().uuidString)")
        paths = LaunchAgentPaths(home: home)
        executable = home.appendingPathComponent("build/calsyn")
        try FileManager.default.createDirectory(at: executable.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "new binary".write(to: executable, atomically: true, encoding: .utf8)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: home)
    }

    private func installedPlist() throws -> AgentPlist {
        try PropertyListDecoder().decode(AgentPlist.self, from: Data(contentsOf: paths.plist))
    }

    func testPaths() {
        XCTAssertEqual(paths.binary.path, "\(home.path)/.calsyn/bin/calsyn")
        XCTAssertEqual(paths.plist.path, "\(home.path)/Library/LaunchAgents/com.totomz.calsyn.plist")
        XCTAssertEqual(paths.log.path, "\(home.path)/Library/Logs/calsyn.log")
    }

    func testInstallCopiesBinaryWritesPlistAndLoadsIt() throws {
        let launchctl = FakeLaunchctl()

        let code = LaunchAgent.install(executable: executable, paths: paths, launchctl: launchctl)

        XCTAssertEqual(code, 0)
        XCTAssertEqual(try String(contentsOf: paths.binary, encoding: .utf8), "new binary")
        let expected = AgentPlist(
            label: "com.totomz.calsyn",
            programArguments: [paths.binary.path, "run"],
            runAtLoad: true,
            keepAlive: true,
            throttleInterval: 300,
            standardOutPath: paths.log.path,
            standardErrorPath: paths.log.path
        )
        XCTAssertEqual(try installedPlist(), expected)
        XCTAssertEqual(launchctl.calls, [
            ["print", "gui/\(getuid())/com.totomz.calsyn"],
            ["bootstrap", "gui/\(getuid())", paths.plist.path],
        ])
    }

    func testReinstallReplacesBinaryAndReloadsAgent() throws {
        try FileManager.default.createDirectory(at: paths.binary.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "old binary".write(to: paths.binary, atomically: true, encoding: .utf8)
        let launchctl = FakeLaunchctl(loaded: true)

        let code = LaunchAgent.install(executable: executable, paths: paths, launchctl: launchctl)

        XCTAssertEqual(code, 0)
        XCTAssertEqual(try String(contentsOf: paths.binary, encoding: .utf8), "new binary")
        XCTAssertEqual(launchctl.calls, [
            ["print", "gui/\(getuid())/com.totomz.calsyn"],
            ["bootout", "gui/\(getuid())/com.totomz.calsyn"],
            ["bootstrap", "gui/\(getuid())", paths.plist.path],
        ])
    }

    func testInstallFailsWhenBootstrapFails() {
        let code = LaunchAgent.install(executable: executable, paths: paths, launchctl: FakeLaunchctl(failing: "bootstrap"))

        XCTAssertNotEqual(code, 0)
    }

    func testInstallFailsWhenBinaryIsMissing() {
        let launchctl = FakeLaunchctl()

        let code = LaunchAgent.install(executable: home.appendingPathComponent("missing"), paths: paths, launchctl: launchctl)

        XCTAssertNotEqual(code, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: paths.plist.path))
        XCTAssertEqual(launchctl.calls, [])
    }

    func testUninstallUnloadsAgentAndRemovesPlist() {
        let launchctl = FakeLaunchctl()
        XCTAssertEqual(LaunchAgent.install(executable: executable, paths: paths, launchctl: launchctl), 0)

        let code = LaunchAgent.uninstall(paths: paths, launchctl: launchctl)

        XCTAssertEqual(code, 0)
        XCTAssertFalse(launchctl.loaded)
        XCTAssertEqual(launchctl.calls.last, ["bootout", "gui/\(getuid())/com.totomz.calsyn"])
        XCTAssertFalse(FileManager.default.fileExists(atPath: paths.plist.path))
    }

    func testUninstallFailsWhenBootoutFails() {
        let launchctl = FakeLaunchctl(loaded: true, failing: "bootout")

        let code = LaunchAgent.uninstall(paths: paths, launchctl: launchctl)

        XCTAssertNotEqual(code, 0)
    }
}
