import Foundation

public enum Runner {
    public static func once(configPath: String, store: some CalendarStore) async -> Int32 {
        let config: Config
        do {
            config = try ConfigLoader.load(path: configPath)
        } catch {
            logConfigError(error, path: configPath)
            return 1
        }
        Log.info("settings loaded", ["calendars": config.calendars.count, "sync_jobs": config.sync.count])
        do {
            try await store.requestAccess()
        } catch {
            error.log()
            return 1
        }
        let window = Reconciler.window(config.window, now: Date())
        for job in config.sync {
            do {
                let result = try Reconciler.reconcile(job: job, calendars: config.calendars, store: store, window: window)
                Log.info("job reconciled", ["job": job.name, "created": result.created, "deleted": result.deleted])
            } catch {
                logJobError(error, job: job.name)
                return 1
            }
        }
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
        case .unknownCalendar(let field, let id):
            Log.error("unknown calendar", ["path": path, "field": field, "calendar": id])
        }
    }

    private static func logJobError(_ error: ReconcileError, job: String) {
        switch error {
        case .calendarNotFound(let id):
            Log.error("calendar not found", ["job": job, "calendar": id])
        case .ambiguousCalendar(let id):
            Log.error("ambiguous calendar", ["job": job, "calendar": id])
        case .store(.calendarNotFound(let id)):
            Log.error("calendar not found", ["job": job, "calendar": id])
        case .store(.writeFailed(let reason)):
            Log.error("calendar write failed", ["job": job, "error": reason])
        }
    }
}
