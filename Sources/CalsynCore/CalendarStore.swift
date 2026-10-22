import EventKit
import Foundation

public struct CalendarInfo: Equatable, Sendable {
    public let account: String
    public let title: String
}

public enum CalendarStoreError: Error, Equatable {
    case accessDenied
    case accessFailed(reason: String)
}

public protocol CalendarStore {
    func requestAccess() async throws(CalendarStoreError)
    func calendars() -> [CalendarInfo]
}

public final class EventKitStore: CalendarStore {
    private let store = EKEventStore()

    public init() {}

    public func requestAccess() async throws(CalendarStoreError) {
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
            CalendarInfo(account: calendar.source?.title ?? "", title: calendar.title)
        }
    }
}
