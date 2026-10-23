import Foundation

public enum CLI {
    // Parses `calsyn <command> [--config <path>]` and dispatches the command.
    // Every usage problem is reported as a logfmt ERROR line and a non-zero exit code.
    public static func main(_ arguments: [String]) async -> Int32 {
        guard let command = arguments.first else {
            Log.error("missing command", ["usage": "calsyn once|calendars [--config <path>]"])
            return 1
        }
        var configPath = ConfigLoader.defaultPath
        var rest = arguments.dropFirst()
        while let argument = rest.popFirst() {
            guard argument == "--config" else {
                Log.error("unknown argument", ["argument": argument])
                return 1
            }
            guard let path = rest.popFirst() else {
                Log.error("missing value", ["argument": argument])
                return 1
            }
            configPath = path
        }
        switch command {
        case "once":
            return await Runner.once(configPath: configPath, store: EventKitStore())
        case "calendars":
            return await listCalendars(store: EventKitStore())
        default:
            Log.error("unknown command", ["command": command])
            return 1
        }
    }

    public static func listCalendars(store: some CalendarStore) async -> Int32 {
        do {
            try await store.requestAccess()
        } catch {
            error.log()
            return 1
        }
        for calendar in store.calendars() {
            Log.info("calendar", ["id": calendar.id, "account": calendar.account, "title": calendar.title])
        }
        return 0
    }
}
