//
//  EventFetcherTests.swift
//  EventFetchingTDDFunTests
//
//  Created by Tom Phillips on 11/6/23.
//

import XCTest
import EventKit

protocol EventStore {
    func events(between startDate: Date, and endDate: Date) -> [Event]
    func connect() -> Bool
    func remove(_ event: Event) throws
    func event(withIdentifier identifier: String) -> Event?
    func save(_ event: Event) throws
}

class MockEventStore: EventStore {
    func remove(_ event: Event) throws {
        if !willConnect {
            throw NSError(domain: "no connection", code: 0)
        }
        scheduledEvents.removeAll { $0.id == event.id }
    }
    
    func event(withIdentifier identifier: String) -> Event? {
        scheduledEvents.first { event in
            event.id == identifier
        }
    }
    
    func connect() -> Bool {
        return willConnect
    }
    
    private var scheduledEvents: [Event]
    private var willConnect: Bool = true
    
    init(scheduledEvents: [Event] = [], willConnect: Bool = true) {
        self.scheduledEvents = scheduledEvents
        self.willConnect = willConnect
    }
    
    func events(between startDate: Date, and endDate: Date) -> [Event] {
        scheduledEvents
    }
    
    func save(_ event: Event) throws {
        scheduledEvents.append(event)
    }
}

class EventService {
    let store: EventStore
    
    enum EventServiceError: Error {
        case couldNotRemoveEvent, eventNotInDatabase, couldNotSaveEvent, couldNotUpdateEvent, scheduleIsBusyAtSelectedDate
    }
    
    init(store: EventStore) {
        self.store = store
    }
    
    func fetchEvents(between startDate: Date, and endDate: Date) -> [Event] {
        let fetchedEvents = store.events(between: startDate, and: endDate)
        
        return fetchedEvents.filter {
            ($0.endDate > startDate && $0.endDate < endDate) || ($0.startDate < endDate && $0.startDate > startDate)
        }
    }
    
    func removeEvent(matching id: Event.ID) throws {
        guard let event = store.event(withIdentifier: id) else {
            throw EventServiceError.eventNotInDatabase
        }
        do { try store.remove(event)} 
        catch { throw EventServiceError.couldNotRemoveEvent }
    }
    
    @discardableResult
    func update(_ event: Event) throws -> Event {
        guard let fetchedEvent = store.event(withIdentifier: event.id) else {
            throw EventServiceError.couldNotUpdateEvent
        }
        
        do {
            try store.remove(fetchedEvent)
            try store.save(event)
        }
        catch { throw EventServiceError.couldNotUpdateEvent }
        
        return event
    }
    
    func schedule(_ event: Event) throws {
        let existingEventsAtSelectedTime = fetchEvents(between: event.startDate, and: event.endDate)
        if !existingEventsAtSelectedTime.isEmpty {
            throw EventServiceError.scheduleIsBusyAtSelectedDate
        }
        do {
            try store.save(event)
        } catch {
            throw EventServiceError.couldNotSaveEvent
        }
    }
}

struct Event: Identifiable, Equatable {
    var startDate: Date
    var endDate: Date
    let id = UUID().uuidString
}

final class EventServiceTests: XCTestCase {
    typealias EventServiceError = EventService.EventServiceError

    func test_fetchEvents_returnsEmptyIfNoDatesScheduledInGivenRange() {
        let store = MockEventStore(scheduledEvents: [])
        let sut = EventService(store: store)
        
        let startDate = makeDate(hour: 8, minute: 0)
        let endDate = makeDate(hour: 12, minute: 0)
        let scheduledEvents = sut.fetchEvents(between: startDate, and: endDate)
        
        XCTAssertEqual(scheduledEvents, [Event]())
    }
    
    func test_fetchEvents_returnsAllScheduledEventsIfAllEventsAreInTheGivenDateRange() {
        let allScheduledEvents = allScheduledEvents()
        let store = MockEventStore(scheduledEvents: allScheduledEvents)
        let sut = EventService(store: store)
        
        let startDate = makeDate(hour: 8, minute: 0)
        let endDate = makeDate(hour: 12, minute: 0)
        let scheduledEvents = sut.fetchEvents(between: startDate, and: endDate)
        
        XCTAssertEqual(scheduledEvents, allScheduledEvents)
    }
    
    func test_fetchEvents_returnsOnlyScheduledEventsInTheGivenDateRange() {
        let allScheduledEvents = allScheduledEvents()
        let store = MockEventStore(scheduledEvents: allScheduledEvents)
        let sut = EventService(store: store)

        let startDate = makeDate(hour: 6, minute: 0)
        let endDate = makeDate(hour: 9, minute: 0)
        let scheduledEvents = sut.fetchEvents(between: startDate, and: endDate)
        
        XCTAssertEqual(scheduledEvents, [allScheduledEvents[0]])
    }
    
    func test_remove_removesEventFromEventStoreMatchingGivenId() throws {
        let originalScheduledEvents = allScheduledEvents()
        let eventToRemove = Event(startDate: makeDate(hour: 8, minute: 0), endDate: makeDate(hour: 9, minute: 0))
        let allScheduledEvents = originalScheduledEvents + [eventToRemove]
        let idToDelete = eventToRemove.id
        let store = MockEventStore(scheduledEvents: allScheduledEvents)
        let sut = EventService(store: store)

        try sut.removeEvent(matching: idToDelete)
        let allEventsAfterRemoval = sut.fetchEvents(between: .distantPast, and: .distantFuture)
        
        XCTAssertEqual(allEventsAfterRemoval, originalScheduledEvents)
    }
    
    func test_remove_throwsIfCannotRemoveEvent() throws {
        let originalScheduledEvents = allScheduledEvents()
        let eventToRemove = Event(startDate: makeDate(hour: 8, minute: 0), endDate: makeDate(hour: 9, minute: 0))
        let allScheduledEvents = originalScheduledEvents + [eventToRemove]
        let store = MockEventStore(scheduledEvents: allScheduledEvents, willConnect: false)
        let sut = EventService(store: store)
        assertDoesThrow(test: {
            try sut.removeEvent(matching: eventToRemove.id)
        }, throws: .couldNotRemoveEvent)
    }
    
    func test_remove_throwsIfEventNotInDatabase() throws {
        let scheduledEvents = allScheduledEvents()
        let eventToRemove = Event(startDate: makeDate(hour: 8, minute: 0), endDate: makeDate(hour: 9, minute: 0))
        let store = MockEventStore(scheduledEvents: scheduledEvents, willConnect: true)
        let sut = EventService(store: store)
        assertDoesThrow(test: {
            try sut.removeEvent(matching: eventToRemove.id)
        }, throws: .eventNotInDatabase)
    }
    
    func test_update_returnsUpdatedEventFromStoreOnSuccess() throws {
        let scheduledEvents = allScheduledEvents()
        var eventToReschedule = scheduledEvents[0]
        let store = MockEventStore(scheduledEvents: scheduledEvents)

        let sut = EventService(store: store)
        eventToReschedule.startDate = makeDate(hour: 6, minute: 15)
        eventToReschedule.endDate = makeDate(hour: 10, minute: 15)
        let updatedEvent = try sut.update(eventToReschedule)
        XCTAssertEqual(eventToReschedule, updatedEvent)
     }
    
    func test_update_throwsCouldNotUpdateEventIfNoDatabaseConnection() throws {
        let scheduledEvents = allScheduledEvents()
        var eventToReschedule = scheduledEvents[0]
        let store = MockEventStore(scheduledEvents: scheduledEvents, willConnect: false)

        let sut = EventService(store: store)
        eventToReschedule.startDate = makeDate(hour: 6, minute: 15)
        eventToReschedule.endDate = makeDate(hour: 10, minute: 15)
        assertDoesThrow(test: {
            try sut.update(eventToReschedule)
        }, throws: .couldNotUpdateEvent)
     }
    
    func test_update_throwsCouldNotUpdateEventIfEventNotInDatabase() throws {
        let scheduledEvents = allScheduledEvents()
        var eventToReschedule = Event(startDate: Date(), endDate: Date())
        let store = MockEventStore(scheduledEvents: scheduledEvents, willConnect: false)

        let sut = EventService(store: store)
        eventToReschedule.startDate = makeDate(hour: 6, minute: 15)
        eventToReschedule.endDate = makeDate(hour: 10, minute: 15)
        assertDoesThrow(test: {
            try sut.update(eventToReschedule)
        }, throws: .couldNotUpdateEvent)
     }
    
    func test_schedule_addsEventToStoreIfCalendarIsFree() throws {
        let store = MockEventStore()
        let sut = EventService(store: store)
        let event = Event(startDate: makeDate(hour: 9, minute: 0), endDate: makeDate(hour: 9, minute: 30))
        try sut.schedule(event)
        let scheduledEvent = sut.fetchEvents(between: .distantPast, and: .distantFuture).first!
        XCTAssertEqual(scheduledEvent, event)
    }
    
    func test_schedule_throwsIfOverlapsWithExistingEvent() {
        let store = MockEventStore(scheduledEvents: allScheduledEvents())
        let sut = EventService(store: store)
        let event = Event(startDate: makeDate(hour: 8, minute: 45), endDate: makeDate(hour: 9, minute: 15))
        assertDoesThrow(test: {
            try sut.schedule(event)
        }, throws: .scheduleIsBusyAtSelectedDate)
    }
    
    // MARK: Helper Methods
    private func makeEvent(startDate: (hour: Int, minute: Int), endDate: (hour: Int, minute: Int)) -> Event {
        Event(
            startDate: makeDate(hour: startDate.hour, minute: startDate.minute),
            endDate: makeDate(hour: endDate.hour, minute: endDate.minute)
        )
    }
    
    private func assertDoesThrow(test action: () throws -> Void, throws expectedError: EventServiceError) {
        do {
            try action()
        } catch let error as EventServiceError where error == expectedError {
            XCTAssert(true)
            return
        } catch {
            XCTFail("expected \(expectedError.localizedDescription) error and got \(error.localizedDescription)")
            return
        }
        XCTFail("expected \(expectedError.localizedDescription) error but did not throw error")
    }
    
    private func makeDate(hour: Int, minute: Int) -> Date {
        Calendar.autoupdatingCurrent.date(bySettingHour: hour, minute: minute, second: 0, of: Date())!
    }
    
    private func allScheduledEvents() -> [Event] {
        let firstEvent = makeEvent(startDate: (hour: 8, minute: 0), endDate: (hour: 8, minute: 30))
        
        let secondEvent = makeEvent(startDate: (hour: 9, minute: 0), endDate: (hour: 9, minute: 15))
        
        
        return [firstEvent, secondEvent]
    }
}
