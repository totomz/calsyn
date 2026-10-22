import Foundation
import Yams

public struct CalendarConfig: Equatable, Sendable {
    public let name: String
    public let account: String
    public let title: String
    public let clonePrefix: String
}

public struct SyncDetails: Equatable, Sendable {
    public let title: Bool
    public let description: Bool
}

public struct SyncJob: Equatable, Sendable {
    public let name: String
    public let source: String
    public let destinations: [String]
    public let details: SyncDetails
}

public struct Config: Equatable, Sendable {
    public let calendars: [CalendarConfig]
    public let sync: [SyncJob]
}

public enum ConfigError: Error, Equatable {
    case unreadable(path: String, reason: String)
    case malformed(field: String, reason: String)
    case missingField(field: String)
    case unknownCalendar(field: String, name: String)
}

private struct RawConfig: Decodable {
    let calendars: [RawCalendar]?
    let sync: [RawJob]?
}

private struct RawCalendar: Decodable {
    let name: String?
    let account: String?
    let title: String?
    let clonePrefix: String?

    enum CodingKeys: String, CodingKey {
        case name
        case account
        case title
        case clonePrefix = "clone_prefix"
    }
}

private struct RawJob: Decodable {
    let name: String?
    let source: String?
    let destinations: [String]?
    let details: RawDetails?
}

private struct RawDetails: Decodable {
    let title: Bool?
    let description: Bool?
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
    // the first missing field, or the first job reference to an undeclared calendar name,
    // is reported with its full path, e.g. `calendars[1].clone_prefix`.
    private static func validate(_ raw: RawConfig) throws(ConfigError) -> Config {
        guard let rawCalendars = raw.calendars else {
            throw .missingField(field: "calendars")
        }
        var calendars: [CalendarConfig] = []
        for (index, item) in rawCalendars.enumerated() {
            let base = "calendars[\(index)]"
            guard let name = item.name else { throw .missingField(field: "\(base).name") }
            guard let account = item.account else { throw .missingField(field: "\(base).account") }
            guard let title = item.title else { throw .missingField(field: "\(base).title") }
            guard let prefix = item.clonePrefix, !prefix.isEmpty else {
                throw .missingField(field: "\(base).clone_prefix")
            }
            calendars.append(CalendarConfig(name: name, account: account, title: title, clonePrefix: prefix))
        }

        guard let rawJobs = raw.sync else {
            throw .missingField(field: "sync")
        }
        let declared = Set(calendars.map(\.name))
        var jobs: [SyncJob] = []
        for (index, item) in rawJobs.enumerated() {
            let base = "sync[\(index)]"
            guard let name = item.name else { throw .missingField(field: "\(base).name") }
            guard let source = item.source else { throw .missingField(field: "\(base).source") }
            guard let destinations = item.destinations else {
                throw .missingField(field: "\(base).destinations")
            }
            guard declared.contains(source) else {
                throw .unknownCalendar(field: "\(base).source", name: source)
            }
            for (destIndex, destination) in destinations.enumerated() where !declared.contains(destination) {
                throw .unknownCalendar(field: "\(base).destinations[\(destIndex)]", name: destination)
            }
            let details = SyncDetails(
                title: item.details?.title ?? false,
                description: item.details?.description ?? false
            )
            jobs.append(SyncJob(name: name, source: source, destinations: destinations, details: details))
        }
        return Config(calendars: calendars, sync: jobs)
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
