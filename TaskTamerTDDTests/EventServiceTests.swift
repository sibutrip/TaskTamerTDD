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
    
    init(scheduledEvents: [Event], willConnect: Bool = true) {
        self.scheduledEvents = scheduledEvents
        self.willConnect = willConnect
    }
    
    func events(between startDate: Date, and endDate: Date) -> [Event] {
        scheduledEvents
    }
}

class EventService {
    let store: EventStore
    
    enum EventServiceError: Error {
        case noConnectionToStore, couldNotRemoveEvent
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
        if let event = store.event(withIdentifier: id) {
            do {
                try store.remove(event)
            } catch {
                throw EventServiceError.couldNotRemoveEvent
            }
        }
    }
}

struct Event: Identifiable, Equatable {
    let startDate: Date
    let endDate: Date
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
        let idToDelete = eventToRemove.id
        let store = MockEventStore(scheduledEvents: allScheduledEvents, willConnect: false)
        let sut = EventService(store: store)
        assertDoesThrow(test: {
            try sut.removeEvent(matching: eventToRemove.id)
        }, throws: .couldNotRemoveEvent)
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
