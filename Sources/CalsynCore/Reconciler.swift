import Foundation

public struct JobResult: Equatable, Sendable {
    public let created: Int
    public let deleted: Int
}

public enum ReconcileError: Error, Equatable {
    case calendarNotFound(id: String)
    case ambiguousCalendar(id: String)
    case store(CalendarStoreError)
}

public enum Reconciler {
    // Makes every destination of the job hold exactly one clone per event of each source in the window.
    // Each source is reconciled on its own: its events are those whose title starts with no configured
    // prefix (RC-01), its clones in a destination are those whose title starts with its prefix (RC-02).
    // Existing clones are matched to the wanted ones by identity, as a multiset: matched clones stay,
    // the others are deleted, then the wanted clones left without a match are created (RC-04).
    // A clone matches a wanted one when title, start, end and all-day flag are all equal, so a clone
    // whose title differs from what the job clones now is replaced; notes are ignored (RC-03, RC-07).
    // No other filter applies: all-day, declined, free and tentative events are cloned too, and the store
    // returns one event per occurrence of a recurring series, each cloned as a standalone event (RC-05, RC-06).
    // Every calendar of the job is resolved before the first write; an empty window reads nothing.
    public static func reconcile(
        job: SyncJob,
        calendars: [CalendarConfig],
        store: some CalendarStore,
        window: DateInterval
    ) throws(ReconcileError) -> JobResult {
        let available = store.calendars()
        var sources: [(prefix: String, calendar: CalendarInfo)] = []
        for id in job.sources {
            sources.append(try resolve(id, calendars: calendars, available: available))
        }
        var destinations: [CalendarInfo] = []
        for id in job.destinations {
            destinations.append(try resolve(id, calendars: calendars, available: available).calendar)
        }
        guard window.duration > 0 else {
            return JobResult(created: 0, deleted: 0)
        }
        let prefixes = calendars.map(\.clonePrefix)
        do {
            var created = 0
            var deleted = 0
            for source in sources {
                let wanted = try store.events(in: source.calendar, during: window)
                    .filter { event in !prefixes.contains { event.content.title.hasPrefix($0) } }
                    .map { clone(of: $0.content, prefix: source.prefix, details: job.details) }
                for destination in destinations {
                    let existing = try store.events(in: destination, during: window)
                        .filter { $0.content.title.hasPrefix(source.prefix) }
                    let (extra, missing) = diff(wanted: wanted, existing: existing)
                    for event in extra {
                        try store.delete(event)
                    }
                    for event in missing {
                        try store.create(event, in: destination)
                    }
                    created += missing.count
                    deleted += extra.count
                }
            }
            return JobResult(created: created, deleted: deleted)
        } catch {
            throw .store(error)
        }
    }

    // Deletes from every destination of the job the events in the window whose title starts with the prefix
    // of one of its sources: every clone the job may have written, whether it matches its source or not.
    // Prefixes come from the config only, so the clones of a source missing from Calendar.app are deleted too.
    public static func cleanup(
        job: SyncJob,
        calendars: [CalendarConfig],
        store: some CalendarStore,
        window: DateInterval
    ) throws(ReconcileError) -> Int {
        let available = store.calendars()
        let prefixes = job.sources.compactMap { id in calendars.first { $0.id == id }?.clonePrefix }
        var destinations: [CalendarInfo] = []
        for id in job.destinations {
            destinations.append(try resolve(id, calendars: calendars, available: available).calendar)
        }
        guard window.duration > 0 else {
            return 0
        }
        do {
            var deleted = 0
            for destination in destinations {
                let clones = try store.events(in: destination, during: window)
                    .filter { event in prefixes.contains { event.content.title.hasPrefix($0) } }
                for event in clones {
                    try store.delete(event)
                }
                deleted += clones.count
            }
            return deleted
        } catch {
            throw .store(error)
        }
    }

    public static func window(_ settings: WindowConfig, now: Date, calendar: Calendar = .current) -> DateInterval {
        let today = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -settings.pastDays, to: today) ?? today
        let end = calendar.date(byAdding: .day, value: settings.futureDays, to: today) ?? today
        return DateInterval(start: start, end: max(start, end))
    }

    static func clone(of source: EventContent, prefix: String, details: SyncDetails) -> EventContent {
        let title = details.title && !source.title.isEmpty ? "\(prefix) \(source.title)" : prefix
        return EventContent(
            title: title,
            notes: details.description ? source.notes : "",
            start: source.start,
            end: source.end,
            isAllDay: source.isAllDay
        )
    }

    private static func diff(
        wanted: [EventContent],
        existing: [StoredEvent]
    ) -> (extra: [StoredEvent], missing: [EventContent]) {
        var missing = wanted
        var extra: [StoredEvent] = []
        for event in existing {
            guard let index = missing.firstIndex(where: { sameClone($0, event.content) }) else {
                extra.append(event)
                continue
            }
            missing.remove(at: index)
        }
        return (extra, missing)
    }

    private static func sameClone(_ wanted: EventContent, _ existing: EventContent) -> Bool {
        wanted.title == existing.title
            && wanted.start == existing.start
            && wanted.end == existing.end
            && wanted.isAllDay == existing.isAllDay
    }

    private static func resolve(
        _ id: String,
        calendars: [CalendarConfig],
        available: [CalendarInfo]
    ) throws(ReconcileError) -> (prefix: String, calendar: CalendarInfo) {
        guard let settings = calendars.first(where: { $0.id == id }), let slash = id.firstIndex(of: "/") else {
            throw .calendarNotFound(id: id)
        }
        let account = id[..<slash]
        let title = id[id.index(after: slash)...]
        let matches = available.filter { $0.account == account && $0.title == title }
        guard matches.count < 2 else {
            throw .ambiguousCalendar(id: id)
        }
        guard let calendar = matches.first else {
            throw .calendarNotFound(id: id)
        }
        return (settings.clonePrefix, calendar)
    }
}
