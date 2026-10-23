@testable import CalsynCore
import Foundation

final class InMemoryCalendarStore: CalendarStore {
    private let available: [CalendarInfo]
    private var stored: [String: [StoredEvent]] = [:]
    private var lastID = 0

    init(calendars: [CalendarInfo]) {
        available = calendars
    }

    func requestAccess() async throws(CalendarAccessError) {}

    func calendars() -> [CalendarInfo] {
        available
    }

    func events(in calendar: CalendarInfo, during window: DateInterval) throws(CalendarStoreError) -> [StoredEvent] {
        stored[calendar.storeID, default: []].filter { $0.content.start < window.end && $0.content.end > window.start }
    }

    func create(_ event: EventContent, in calendar: CalendarInfo) throws(CalendarStoreError) {
        lastID += 1
        stored[calendar.storeID, default: []].append(StoredEvent(id: "\(lastID)", content: event))
    }

    func delete(_ event: StoredEvent) throws(CalendarStoreError) {
        for key in stored.keys {
            stored[key]?.removeAll { $0.id == event.id }
        }
    }
}
