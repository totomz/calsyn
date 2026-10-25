import Foundation

public struct LaunchAgentPaths: Equatable, Sendable {
    public let binary: URL
    public let plist: URL
    public let log: URL

    public init(home: URL = FileManager.default.homeDirectoryForCurrentUser, binDirectory: URL? = nil) {
        binary = (binDirectory ?? home.appendingPathComponent("bin")).appendingPathComponent("calsyn")
        plist = home.appendingPathComponent("Library/LaunchAgents/\(LaunchAgent.label).plist")
        log = home.appendingPathComponent("Library/Logs/calsyn.log")
    }
}

public struct AgentPlist: Codable, Equatable, Sendable {
    public let label: String
    public let programArguments: [String]
    public let runAtLoad: Bool
    public let keepAlive: Bool
    public let throttleInterval: Int
    public let standardOutPath: String
    public let standardErrorPath: String

    enum CodingKeys: String, CodingKey {
        case label = "Label"
        case programArguments = "ProgramArguments"
        case runAtLoad = "RunAtLoad"
        case keepAlive = "KeepAlive"
        case throttleInterval = "ThrottleInterval"
        case standardOutPath = "StandardOutPath"
        case standardErrorPath = "StandardErrorPath"
    }
}

public enum LaunchAgentError: Error, Equatable {
    case copyFailed(path: String, reason: String)
    case writeFailed(path: String, reason: String)
    case removeFailed(path: String, reason: String)
    case launchctlFailed(command: String, status: Int32, output: String)
}

public struct LaunchctlResult: Equatable, Sendable {
    public let status: Int32
    public let output: String
}

public protocol Launchctl {
    func run(_ arguments: [String]) -> LaunchctlResult
}

public struct SystemLaunchctl: Launchctl {
    public init() {}

    public func run(_ arguments: [String]) -> LaunchctlResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
        } catch {
            return LaunchctlResult(status: -1, output: error.localizedDescription)
        }
        let output = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let text = String(decoding: output, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return LaunchctlResult(status: process.terminationStatus, output: text)
    }
}

public enum LaunchAgent {
    public static let label = "com.totomz.calsyn"

    static var domain: String {
        "gui/\(getuid())"
    }

    static var service: String {
        "\(domain)/\(label)"
    }

    // Asks the folder the binary is copied to: Enter alone picks `~/bin`, a leading `~` stands for `home`
    // and a relative path is taken from the current directory. Nil when the input ends without an answer.
    public static func binDirectory(home: URL, prompter: some Prompter) -> URL? {
        guard let answer = prompter.ask("Where to install the binary? [~/bin]") else {
            return nil
        }
        let path = answer.trimmingCharacters(in: .whitespaces)
        if path.isEmpty {
            return home.appendingPathComponent("bin")
        }
        if path == "~" {
            return home
        }
        if path.hasPrefix("~/") {
            return home.appendingPathComponent(String(path.dropFirst(2)))
        }
        return URL(fileURLWithPath: path)
    }

    public static func plist(_ paths: LaunchAgentPaths) -> AgentPlist {
        AgentPlist(
            label: label,
            programArguments: [paths.binary.path, "run"],
            runAtLoad: true,
            keepAlive: true,
            throttleInterval: 300,
            standardOutPath: paths.log.path,
            standardErrorPath: paths.log.path
        )
    }

    // Copies the running executable to `paths.binary`, writes the plist and loads it in the user session.
    // An agent already loaded is booted out right before the bootstrap, so a reinstall restarts it
    // on the new binary; a failed copy or plist write leaves the running agent untouched.
    public static func install(executable: URL, paths: LaunchAgentPaths, launchctl: some Launchctl) -> Int32 {
        do {
            try copy(executable, to: paths.binary)
            try write(plist(paths), to: paths.plist)
            try unload(launchctl)
            try run(["bootstrap", domain, paths.plist.path], launchctl)
        } catch {
            error.log()
            return 1
        }
        Log.info("agent installed", ["label": label, "binary": paths.binary.path, "plist": paths.plist.path, "log": paths.log.path])
        return 0
    }

    public static func uninstall(paths: LaunchAgentPaths, launchctl: some Launchctl) -> Int32 {
        do {
            try unload(launchctl)
            try remove(paths.plist)
        } catch {
            error.log()
            return 1
        }
        Log.info("agent uninstalled", ["label": label, "plist": paths.plist.path])
        return 0
    }

    private static func copy(_ executable: URL, to binary: URL) throws(LaunchAgentError) {
        let fileManager = FileManager.default
        let staging = binary.appendingPathExtension("new")
        do {
            try fileManager.createDirectory(at: binary.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? fileManager.removeItem(at: staging)
            try fileManager.copyItem(at: executable, to: staging)
            _ = try fileManager.replaceItemAt(binary, withItemAt: staging)
        } catch {
            throw .copyFailed(path: binary.path, reason: error.localizedDescription)
        }
    }

    private static func write(_ plist: AgentPlist, to url: URL) throws(LaunchAgentError) {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try encoder.encode(plist).write(to: url, options: .atomic)
        } catch {
            throw .writeFailed(path: url.path, reason: error.localizedDescription)
        }
    }

    private static func remove(_ url: URL) throws(LaunchAgentError) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return
        }
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            throw .removeFailed(path: url.path, reason: error.localizedDescription)
        }
    }

    private static func unload(_ launchctl: some Launchctl) throws(LaunchAgentError) {
        guard launchctl.run(["print", service]).status == 0 else {
            return
        }
        try run(["bootout", service], launchctl)
    }

    private static func run(_ arguments: [String], _ launchctl: some Launchctl) throws(LaunchAgentError) {
        let result = launchctl.run(arguments)
        guard result.status == 0 else {
            throw .launchctlFailed(command: arguments.joined(separator: " "), status: result.status, output: result.output)
        }
    }
}

extension LaunchAgentError {
    func log() {
        switch self {
        case .copyFailed(let path, let reason):
            Log.error("binary copy failed", ["path": path, "error": reason])
        case .writeFailed(let path, let reason):
            Log.error("plist write failed", ["path": path, "error": reason])
        case .removeFailed(let path, let reason):
            Log.error("plist remove failed", ["path": path, "error": reason])
        case .launchctlFailed(let command, let status, let output):
            Log.error("launchctl failed", ["command": command, "status": status, "error": output])
        }
    }
}
