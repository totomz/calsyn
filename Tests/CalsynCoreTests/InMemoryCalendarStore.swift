@testable import CalsynCore
import EventKit
import Foundation

// Mirrors EventKitStore: a recurring series is stored once and read back as one event per occurrence,
// each with its own id so that `delete` removes only that occurrence. A series repeats daily on the given
// weekdays (`Calendar` weekday numbers in UTC, 1 = Sunday). Availability and participation status are kept
// on the stored event but, as in EventKitStore, only the event content is handed to the reconciler.
final class InMemoryCalendarStore: CalendarStore {
    private struct Entry {
        let id: String
        let content: EventContent
        let availability: EKEventAvailability
        let participation: EKParticipantStatus
        let weekdays: Set<Int>
    }

    private let available: [CalendarInfo]
    private let utc: Calendar
    private var stored: [String: [Entry]] = [:]
    private var deleted: Set<String> = []
    private var lastID = 0

    init(calendars: [CalendarInfo]) {
        available = calendars
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        self.utc = utc
    }

    func requestAccess() async throws(CalendarAccessError) {}

    func calendars() -> [CalendarInfo] {
        available
    }

    func events(in calendar: CalendarInfo, during window: DateInterval) throws(CalendarStoreError) -> [StoredEvent] {
        stored[calendar.storeID, default: []]
            .flatMap { occurrences(of: $0, until: window.end) }
            .filter { !deleted.contains($0.id) && $0.content.start < window.end && $0.content.end > window.start }
    }

    func create(_ event: EventContent, in calendar: CalendarInfo) throws(CalendarStoreError) {
        add(event, to: calendar)
    }

    func add(
        _ event: EventContent,
        to calendar: CalendarInfo,
        availability: EKEventAvailability = .busy,
        participation: EKParticipantStatus = .accepted,
        repeatingOn weekdays: Set<Int> = []
    ) {
        lastID += 1
        let entry = Entry(id: "\(lastID)", content: event, availability: availability, participation: participation, weekdays: weekdays)
        stored[calendar.storeID, default: []].append(entry)
    }

    func delete(_ event: StoredEvent) throws(CalendarStoreError) {
        deleted.insert(event.id)
    }

    // Expands a series into one occurrence per day from its first start up to `end`, keeping only the days
    // whose weekday is in the rule. A single event is its own only occurrence.
    private func occurrences(of entry: Entry, until end: Date) -> [StoredEvent] {
        guard !entry.weekdays.isEmpty else {
            return [StoredEvent(id: entry.id, content: entry.content)]
        }
        let duration = entry.content.end.timeIntervalSince(entry.content.start)
        var result: [StoredEvent] = []
        var day = 0
        while let start = utc.date(byAdding: .day, value: day, to: entry.content.start), start < end {
            if entry.weekdays.contains(utc.component(.weekday, from: start)) {
                let content = EventContent(
                    title: entry.content.title,
                    notes: entry.content.notes,
                    start: start,
                    end: start.addingTimeInterval(duration),
                    isAllDay: entry.content.isAllDay
                )
                result.append(StoredEvent(id: "\(entry.id)/\(day)", content: content))
            }
            day += 1
        }
        return result
    }
}
