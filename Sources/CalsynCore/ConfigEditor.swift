import Foundation

public enum ConfigEditorError: Error, Equatable {
    case createFailed(path: String, reason: String)
    case openFailed(path: String, status: Int32, output: String)
}

public struct OpenResult: Equatable, Sendable {
    public let status: Int32
    public let output: String
}

public protocol Opener {
    func open(_ path: String) -> OpenResult
}

public struct SystemOpener: Opener {
    public init() {}

    public func open(_ path: String) -> OpenResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-t", path]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
        } catch {
            return OpenResult(status: -1, output: error.localizedDescription)
        }
        let output = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let text = String(decoding: output, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return OpenResult(status: process.terminationStatus, output: text)
    }
}

public enum ConfigEditor {
    // Makes sure the config file exists and is not blank before going on. A missing or blank file is
    // created and opened in the text editor, then the user is asked to confirm with Enter; the question
    // is repeated until the file holds something. Fails when the file cannot be opened or the input ends.
    public static func ensure(path: String, opener: some Opener, prompter: some Prompter) -> Int32 {
        guard !hasContent(path) else {
            return 0
        }
        Log.info("config missing", ["path": path])
        guard open(path: path, opener: opener) == 0 else {
            return 1
        }
        while prompter.ask("Config done? Press Enter to continue") != nil {
            if hasContent(path) {
                Log.info("config ready", ["path": path])
                return 0
            }
            Log.error("config missing or empty", ["path": path])
        }
        Log.error("config not confirmed", ["path": path])
        return 1
    }

    public static func open(path: String, opener: some Opener) -> Int32 {
        do {
            try createIfMissing(path)
            try run(opener, path)
        } catch {
            error.log()
            return 1
        }
        Log.info("config opened", ["path": path])
        return 0
    }

    private static func run(_ opener: some Opener, _ path: String) throws(ConfigEditorError) {
        let result = opener.open(path)
        guard result.status == 0 else {
            throw .openFailed(path: path, status: result.status, output: result.output)
        }
    }

    private static func hasContent(_ path: String) -> Bool {
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else {
            return false
        }
        return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func createIfMissing(_ path: String) throws(ConfigEditorError) {
        guard !FileManager.default.fileExists(atPath: path) else {
            return
        }
        let url = URL(fileURLWithPath: path)
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data().write(to: url, options: .withoutOverwriting)
        } catch {
            throw .createFailed(path: path, reason: error.localizedDescription)
        }
    }
}

extension ConfigEditorError {
    func log() {
        switch self {
        case .createFailed(let path, let reason):
            Log.error("config create failed", ["path": path, "error": reason])
        case .openFailed(let path, let status, let output):
            Log.error("config open failed", ["path": path, "status": status, "error": output])
        }
    }
}
