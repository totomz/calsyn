import Foundation

public enum Runner {
    public static func once(configPath: String) -> Int32 {
        let config: Config
        do {
            config = try ConfigLoader.load(path: configPath)
        } catch {
            logConfigError(error, path: configPath)
            return 1
        }
        Log.info("settings loaded", ["calendars": config.calendars.count, "sync_jobs": config.sync.count])
        return 0
    }

    private static func logConfigError(_ error: ConfigError, path: String) {
        switch error {
        case .unreadable(let path, let reason):
            Log.error("config not readable", ["path": path, "error": reason])
        case .malformed(let field, let reason):
            Log.error("invalid config", ["path": path, "field": field, "error": reason])
        case .missingField(let field):
            Log.error("missing required field", ["path": path, "field": field])
        case .unknownCalendar(let field, let name):
            Log.error("unknown calendar name", ["path": path, "field": field, "name": name])
        }
    }
}
