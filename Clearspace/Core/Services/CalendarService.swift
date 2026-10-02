import EventKit

// EventKit objects stay on this actor; only immutable snapshots cross to the UI.
actor CalendarService {
    private let database = EKEventStore()

    func requestAccess() async throws -> Bool {
        try await database.requestFullAccessToEvents()
    }

    private func snapshot(_ event: EKEvent) -> CalendarItem? {
        guard let id = event.eventIdentifier, let start = event.startDate, let end = event.endDate,
              CalendarCleanupPolicy.eligible(start: start, end: end,
                writable: event.calendar.allowsContentModifications,
                recurring: event.hasRecurrenceRules, detached: event.isDetached,
                invitation: event.hasAttendees || event.organizer != nil) else { return nil }
        return CalendarItem(id: id, title: event.title ?? "Untitled event",
            calendarID: event.calendar.calendarIdentifier, calendarTitle: event.calendar.title,
            start: start, end: end, modified: event.lastModifiedDate,
            location: event.location, notes: event.notes, allDay: event.isAllDay)
    }

    func scan() throws -> [CalendarItem] {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else {
            throw CalendarCleanupError.access
        }
        database.reset()
        let now = Date()
        let start = Calendar.current.date(byAdding: .year, value: -1, to: now)!
        let end = Calendar.current.date(byAdding: .day, value: -30, to: now)!
        let calendars = database.calendars(for: .event).filter(\.allowsContentModifications)
        guard !calendars.isEmpty else { return [] }
        let predicate = database.predicateForEvents(withStart: start, end: end, calendars: calendars)
        var seen = Set<String>()
        return database.events(matching: predicate).compactMap(snapshot)
            .filter { seen.insert($0.id).inserted }.sorted { $0.start > $1.start }
    }

    func delete(_ reviewed: [CalendarItem]) throws {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else {
            throw CalendarCleanupError.access
        }
        guard !reviewed.isEmpty, Set(reviewed.map(\.id)).count == reviewed.count else {
            throw CalendarCleanupError.stale
        }
        database.reset()
        // Validate the entire review before staging any removal.
        let events = try reviewed.map { item -> EKEvent in
            guard let event = database.event(withIdentifier: item.id), snapshot(event) == item else {
                throw CalendarCleanupError.stale
            }
            return event
        }
        do {
            for event in events { try database.remove(event, span: .thisEvent, commit: false) }
            try database.commit()
        } catch {
            database.reset()
            throw error
        }
    }
    #if DEBUG
    // Explicit developer action only; never runs at launch or during a scan.
    func addTestEvents() throws {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else {
            throw CalendarCleanupError.access
        }
        database.reset()
        guard let source = database.defaultCalendarForNewEvents?.source
            ?? database.sources.first(where: { $0.sourceType == .local }) else {
            throw NSError(domain: "PipSweep.Calendar", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "No writable calendar source is available. Add a Calendar account in Settings, then try again."])
        }
        let calendar = EKCalendar(for: .event, eventStore: database)
        calendar.title = "PipSweep Test \(Date().formatted(date: .omitted, time: .standard))"
        calendar.source = source
        do {
            try database.saveCalendar(calendar, commit: false)
            for (title, days, repeats) in [
                ("TEST - Old event A", -60, false), ("TEST - Old event B", -90, false),
                ("TEST - Recent event", -7, false), ("TEST - Future event", 7, false),
                ("TEST - Repeating event", -60, true)
            ] {
                let event = EKEvent(eventStore: database)
                event.calendar = calendar
                event.title = title
                event.startDate = Calendar.current.date(byAdding: .day, value: days, to: Date())!
                event.endDate = event.startDate.addingTimeInterval(3600)
                event.notes = "Disposable PipSweep test event."
                if repeats {
                    event.addRecurrenceRule(EKRecurrenceRule(recurrenceWith: .weekly, interval: 1,
                        end: EKRecurrenceEnd(occurrenceCount: 12)))
                }
                try database.save(event, span: .thisEvent, commit: false)
            }
            try database.commit()
        } catch { database.reset(); throw error }
    }
    #endif

}
