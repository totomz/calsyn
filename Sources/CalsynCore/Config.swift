import Foundation
import Yams

public struct CalendarConfig: Equatable, Sendable {
    public let id: String
    public let clonePrefix: String
}

public struct SyncDetails: Equatable, Sendable {
    public let title: Bool
    public let description: Bool
}

public struct SyncJob: Equatable, Sendable {
    public let name: String
    public let sources: [String]
    public let destinations: [String]
    public let details: SyncDetails
    public let cleanup: Bool
}

public struct WindowConfig: Equatable, Sendable {
    public let pastDays: Int
    public let futureDays: Int
}

public struct Config: Equatable, Sendable {
    public let calendars: [CalendarConfig]
    public let sync: [SyncJob]
    public let window: WindowConfig
}

public enum ConfigError: Error, Equatable {
    case unreadable(path: String, reason: String)
    case malformed(field: String, reason: String)
    case missingField(field: String)
    case unknownCalendar(field: String, id: String)
}

private struct RawConfig: Decodable {
    let calendars: [RawCalendar]?
    let sync: [RawJob]?
    let window: RawWindow?
}

private struct RawCalendar: Decodable {
    let id: String?
    let clonePrefix: String?

    enum CodingKeys: String, CodingKey {
        case id
        case clonePrefix = "clone_prefix"
    }
}

private struct RawJob: Decodable {
    let name: String?
    let sources: [String]?
    let destinations: [String]?
    let details: RawDetails?
    let cleanup: Bool?
}

private struct RawDetails: Decodable {
    let title: Bool?
    let description: Bool?
}

private struct RawWindow: Decodable {
    let pastDays: Int?
    let futureDays: Int?

    enum CodingKeys: String, CodingKey {
        case pastDays = "past_days"
        case futureDays = "future_days"
    }
}

public enum ConfigLoader {
    public static var defaultPath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/calsyn/config.yaml")
            .path
    }

    public static func load(path: String) throws(ConfigError) -> Config {
        let text: String
        do {
            text = try String(contentsOfFile: path, encoding: .utf8)
        } catch {
            throw .unreadable(path: path, reason: error.localizedDescription)
        }
        return try parse(text)
    }

    public static func parse(_ text: String) throws(ConfigError) -> Config {
        let raw: RawConfig
        do {
            raw = try YAMLDecoder().decode(RawConfig.self, from: text)
        } catch let error as DecodingError {
            throw describe(error)
        } catch {
            throw .malformed(field: "", reason: String(describing: error))
        }
        return try validate(raw)
    }

    // Turns the raw document into a Config. Every field without a default is required;
    // the first missing field, or the first job reference to an undeclared calendar id,
    // is reported with its full path, e.g. `calendars[1].clone_prefix`.
    private static func validate(_ raw: RawConfig) throws(ConfigError) -> Config {
        guard let rawCalendars = raw.calendars else {
            throw .missingField(field: "calendars")
        }
        var calendars: [CalendarConfig] = []
        for (index, item) in rawCalendars.enumerated() {
            let base = "calendars[\(index)]"
            guard let id = item.id else { throw .missingField(field: "\(base).id") }
            guard let prefix = item.clonePrefix, !prefix.isEmpty else {
                throw .missingField(field: "\(base).clone_prefix")
            }
            calendars.append(CalendarConfig(id: id, clonePrefix: prefix))
        }

        guard let rawJobs = raw.sync else {
            throw .missingField(field: "sync")
        }
        let declared = Set(calendars.map(\.id))
        var jobs: [SyncJob] = []
        for (index, item) in rawJobs.enumerated() {
            let base = "sync[\(index)]"
            guard let name = item.name else { throw .missingField(field: "\(base).name") }
            guard let sources = item.sources else { throw .missingField(field: "\(base).sources") }
            guard let destinations = item.destinations else {
                throw .missingField(field: "\(base).destinations")
            }
            for (sourceIndex, source) in sources.enumerated() where !declared.contains(source) {
                throw .unknownCalendar(field: "\(base).sources[\(sourceIndex)]", id: source)
            }
            for (destIndex, destination) in destinations.enumerated() where !declared.contains(destination) {
                throw .unknownCalendar(field: "\(base).destinations[\(destIndex)]", id: destination)
            }
            let details = SyncDetails(
                title: item.details?.title ?? false,
                description: item.details?.description ?? false
            )
            jobs.append(SyncJob(
                name: name,
                sources: sources,
                destinations: destinations,
                details: details,
                cleanup: item.cleanup ?? false
            ))
        }
        let window = WindowConfig(
            pastDays: raw.window?.pastDays ?? 0,
            futureDays: raw.window?.futureDays ?? 7
        )
        return Config(calendars: calendars, sync: jobs, window: window)
    }

    private static func describe(_ error: DecodingError) -> ConfigError {
        switch error {
        case .typeMismatch(_, let context), .valueNotFound(_, let context),
             .keyNotFound(_, let context), .dataCorrupted(let context):
            return .malformed(field: fieldPath(context.codingPath), reason: context.debugDescription)
        @unknown default:
            return .malformed(field: "", reason: String(describing: error))
        }
    }

    private static func fieldPath(_ codingPath: [any CodingKey]) -> String {
        var path = ""
        for key in codingPath {
            if let index = key.intValue {
                path.append("[\(index)]")
                continue
            }
            path.append(path.isEmpty ? key.stringValue : ".\(key.stringValue)")
        }
        return path
    }
}
