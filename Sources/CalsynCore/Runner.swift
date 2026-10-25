import Foundation

public enum Runner {
    public static let interval: Duration = .seconds(300)

    public static func once(configPath: String, store: some CalendarStore) async -> Int32 {
        guard let config = loadConfig(path: configPath) else {
            return 1
        }
        do {
            try await store.requestAccess()
        } catch {
            error.log()
            return 1
        }
        return reconcile(config, store: store) ? 0 : 1
    }

    public static func cleanup(configPath: String, store: some CalendarStore) async -> Int32 {
        guard let config = loadConfig(path: configPath) else {
            return 1
        }
        do {
            try await store.requestAccess()
        } catch {
            error.log()
            return 1
        }
        let window = Reconciler.window(config.window, now: Date())
        for job in config.sync where job.cleanup {
            do {
                let deleted = try Reconciler.cleanup(job: job, calendars: config.calendars, store: store, window: window)
                Log.info("job cleaned", ["job": job.name, "deleted": deleted])
            } catch {
                logJobError(error, job: job.name)
                return 1
            }
        }
        return 0
    }

    public static func run(configPath: String, store: some CalendarStore, triggers: AsyncStream<Void>) async -> Int32 {
        do {
            try await store.requestAccess()
        } catch {
            error.log()
            return 1
        }
        reconcile(configPath: configPath, store: store)
        for await _ in triggers {
            reconcile(configPath: configPath, store: store)
        }
        return 0
    }

    // Builds the triggers of `run`: one on every change of the store and one every `interval`.
    // The stream holds at most one pending trigger, so all the changes notified while a reconcile runs,
    // its own writes included, lead to a single further reconcile. That reconcile writes nothing when
    // nothing else changed, so it notifies nothing and the loop goes idle until the next trigger.
    public static func triggers(store: EventKitStore, every interval: Duration) -> AsyncStream<Void> {
        let (triggers, continuation) = AsyncStream.makeStream(of: Void.self, bufferingPolicy: .bufferingNewest(1))
        store.onChange {
            Log.info("calendar changed")
            continuation.yield()
        }
        let timer = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                continuation.yield()
            }
        }
        continuation.onTermination = { _ in timer.cancel() }
        return triggers
    }

    private static func reconcile(configPath: String, store: some CalendarStore) {
        if let config = loadConfig(path: configPath) {
            reconcile(config, store: store)
        }
    }

    private static func loadConfig(path: String) -> Config? {
        let config: Config
        do {
            config = try ConfigLoader.load(path: path)
        } catch {
            logConfigError(error, path: path)
            return nil
        }
        Log.info("settings loaded", ["calendars": config.calendars.count, "sync_jobs": config.sync.count])
        return config
    }

    @discardableResult
    private static func reconcile(_ config: Config, store: some CalendarStore) -> Bool {
        let window = Reconciler.window(config.window, now: Date())
        for job in config.sync {
            do {
                let result = try Reconciler.reconcile(job: job, calendars: config.calendars, store: store, window: window)
                Log.info("job reconciled", ["job": job.name, "created": result.created, "deleted": result.deleted])
            } catch {
                logJobError(error, job: job.name)
                return false
            }
        }
        return true
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
