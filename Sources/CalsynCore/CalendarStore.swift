import EventKit
import Foundation

public struct CalendarInfo: Equatable, Sendable {
    public let storeID: String
    public let account: String
    public let title: String

    public var id: String {
        "\(account)/\(title)"
    }
}

public struct EventContent: Equatable, Sendable {
    public let title: String
    public let notes: String
    public let start: Date
    public let end: Date
    public let isAllDay: Bool
}

public struct StoredEvent: Equatable, Sendable {
    public let id: String
    public let content: EventContent
}

public enum CalendarAccessError: Error, Equatable {
    case accessDenied
    case accessFailed(reason: String)
}

public enum CalendarStoreError: Error, Equatable {
    case calendarNotFound(id: String)
    case writeFailed(reason: String)
}

public protocol CalendarStore {
    func requestAccess() async throws(CalendarAccessError)
    func calendars() -> [CalendarInfo]
    func events(in calendar: CalendarInfo, during window: DateInterval) throws(CalendarStoreError) -> [StoredEvent]
    func create(_ event: EventContent, in calendar: CalendarInfo) throws(CalendarStoreError)
    func delete(_ event: StoredEvent) throws(CalendarStoreError)
}

public final class EventKitStore: CalendarStore {
    private let store = EKEventStore()
    private var loaded: [String: EKEvent] = [:]

    public init() {}

    public func requestAccess() async throws(CalendarAccessError) {
        let granted: Bool
        do {
            granted = try await store.requestFullAccessToEvents()
        } catch {
            throw .accessFailed(reason: error.localizedDescription)
        }
        guard granted else {
            throw .accessDenied
        }
    }

    public func calendars() -> [CalendarInfo] {
        store.calendars(for: .event).map { calendar in
            CalendarInfo(storeID: calendar.calendarIdentifier, account: calendar.source?.title ?? "", title: calendar.title)
        }
    }

    // Returns every occurrence overlapping the window. Each occurrence gets its own id and is kept
    // until the next read of the same calendar, so `delete` removes exactly that occurrence even when
    // it belongs to a recurring series (all occurrences of a series share the same eventIdentifier).
    public func events(in calendar: CalendarInfo, during window: DateInterval) throws(CalendarStoreError) -> [StoredEvent] {
        let ekCalendar = try find(calendar)
        let predicate = store.predicateForEvents(withStart: window.start, end: window.end, calendars: [ekCalendar])
        loaded = loaded.filter { $0.value.calendar?.calendarIdentifier != calendar.storeID }
        return store.events(matching: predicate).map { event in
            let id = UUID().uuidString
            loaded[id] = event
            let content = EventContent(
                title: event.title ?? "",
                notes: event.notes ?? "",
                start: event.startDate,
                end: event.endDate,
                isAllDay: event.isAllDay
            )
            return StoredEvent(id: id, content: content)
        }
    }

    public func create(_ event: EventContent, in calendar: CalendarInfo) throws(CalendarStoreError) {
        let clone = EKEvent(eventStore: store)
        clone.calendar = try find(calendar)
        clone.title = event.title
        clone.notes = event.notes.isEmpty ? nil : event.notes
        clone.startDate = event.start
        clone.endDate = event.end
        clone.isAllDay = event.isAllDay
        do {
            try store.save(clone, span: .thisEvent, commit: true)
        } catch {
            throw .writeFailed(reason: error.localizedDescription)
        }
    }

    public func delete(_ event: StoredEvent) throws(CalendarStoreError) {
        guard let target = loaded.removeValue(forKey: event.id) else {
            throw .writeFailed(reason: "event \(event.id) was not read from the store")
        }
        do {
            try store.remove(target, span: .thisEvent, commit: true)
        } catch {
            throw .writeFailed(reason: error.localizedDescription)
        }
    }

    private func find(_ calendar: CalendarInfo) throws(CalendarStoreError) -> EKCalendar {
        guard let found = store.calendar(withIdentifier: calendar.storeID) else {
            throw .calendarNotFound(id: calendar.id)
        }
        return found
    }
}

extension CalendarAccessError {
    func log() {
        switch self {
        case .accessDenied:
            Log.error("calendar access denied")
        case .accessFailed(let reason):
            Log.error("calendar access failed", ["error": reason])
        }
    }
}
