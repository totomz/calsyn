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
