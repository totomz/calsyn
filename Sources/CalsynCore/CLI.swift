import Foundation

public enum CLI {
    // Parses `calsyn <command> [--config <path>]` and dispatches the command; `install` and `uninstall` take no arguments.
    // Every usage problem is reported as a logfmt ERROR line and a non-zero exit code.
    public static func main(_ arguments: [String], opener: some Opener = SystemOpener()) async -> Int32 {
        guard let command = arguments.first else {
            Log.error("missing command", ["usage": "calsyn once|run|cleanup|calendars|config [--config <path>] | calsyn install|uninstall"])
            return 1
        }
        var configPath = ConfigLoader.defaultPath
        var rest = arguments.dropFirst()
        let acceptsConfig = command != "install" && command != "uninstall"
        while let argument = rest.popFirst() {
            guard argument == "--config", acceptsConfig else {
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
        case "run":
            let store = EventKitStore()
            let triggers = Runner.triggers(store: store, every: Runner.interval)
            return await Runner.run(configPath: configPath, store: store, triggers: triggers)
        case "cleanup":
            return await Runner.cleanup(configPath: configPath, store: EventKitStore())
        case "calendars":
            return await listCalendars(store: EventKitStore())
        case "config":
            return ConfigEditor.open(path: configPath, opener: opener)
        case "install":
            guard let executable = Bundle.main.executableURL else {
                Log.error("executable not found")
                return 1
            }
            return LaunchAgent.install(executable: executable.resolvingSymlinksInPath(), paths: LaunchAgentPaths(), launchctl: SystemLaunchctl())
        case "uninstall":
            return LaunchAgent.uninstall(paths: LaunchAgentPaths(), launchctl: SystemLaunchctl())
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
