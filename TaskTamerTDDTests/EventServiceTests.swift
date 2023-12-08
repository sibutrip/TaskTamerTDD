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
        scheduledEvents.removeAll { $0.id == event.id
        }
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
    
    enum Error: Swift.Error {
        case noConnectionToStore
    }
    
    init(store: EventStore) throws{
        if store.connect() {
            self.store = store
        } else {
            throw Error.noConnectionToStore
        }
    }
    
    func fetchDates(between startDate: Date, and endDate: Date) -> [Event] {
        let fetchedEvents = store.events(between: startDate, and: endDate)
        
        return fetchedEvents.filter {
            ($0.endDate > startDate && $0.endDate < endDate) || ($0.startDate < endDate && $0.startDate > startDate)
        }
    }
    
    func removeEvent(matching id: String) {
        if let event = store.event(withIdentifier: id) {
            try? store.remove(event)
        }
    }
}

struct Event: Equatable {
    let startDate: Date
    let endDate: Date
    let id = UUID().uuidString
}

final class EventServiceTests: XCTestCase {

    func test_fetchEvents_returnsEmptyIfNoDatesScheduledInGivenRange() {
        let store = MockEventStore(scheduledEvents: [])
        let sut = try! EventService(store: store)
        let startDate = makeDate(hour: 8, minute: 0)
        let endDate = makeDate(hour: 12, minute: 0)
        
        let scheduledEvents = sut.fetchDates(between: startDate, and: endDate)
        XCTAssertEqual(scheduledEvents, [Event]())
    }
    
    func test_fetchEvents_returnsAllScheduledEventsIfAllEventsAreInTheGivenDateRange() {
        let allScheduledEvents = allScheduledEvents()
        let store = MockEventStore(scheduledEvents: allScheduledEvents)
        let sut = try! EventService(store: store)
    
        let startDate = makeDate(hour: 8, minute: 0)
        let endDate = makeDate(hour: 12, minute: 0)
        
        let scheduledEvents = sut.fetchDates(between: startDate, and: endDate)
        XCTAssertEqual(scheduledEvents, allScheduledEvents)
    }
    
    func test_fetchEvents_returnsOnlyScheduledEventsInTheGivenDateRange() {
        let allScheduledEvents = allScheduledEvents()
        let store = MockEventStore(scheduledEvents: allScheduledEvents)
        let sut = try! EventService(store: store)
    
        let startDate = makeDate(hour: 6, minute: 0)
        let endDate = makeDate(hour: 9, minute: 0)
        
        let scheduledEvents = sut.fetchDates(between: startDate, and: endDate)
        XCTAssertEqual(scheduledEvents, [allScheduledEvents[0]])
    }
    
    // TODO: How can I cover more edge cases with fetching events from different ranges?
    
    func test_fetchEvents_throwsNoConnectionToEventStoreErrorIfEventsAreNotAbleToBeFetched() {
        let store = MockEventStore(scheduledEvents: [], willConnect: false)
        XCTAssertThrowsError(try EventService(store: store))
    }
    
    func test_remove_removesEventFromEventStoreMatchingGivenId() {
        let originalScheduledEvents = allScheduledEvents()
        let eventToRemove = Event(startDate: makeDate(hour: 8, minute: 0), endDate: makeDate(hour: 9, minute: 0))
        let allScheduledEvents = originalScheduledEvents + [eventToRemove]
        let idToDelete = eventToRemove.id
        let store = MockEventStore(scheduledEvents: allScheduledEvents)
        let sut = try! EventService(store: store)

        sut.removeEvent(matching: idToDelete)
        let allEventsAfterRemoval = sut.fetchDates(between: .distantPast, and: .distantFuture)
        
        XCTAssertEqual(allEventsAfterRemoval, originalScheduledEvents)
    }
    
    // MARK: Helper Methods
    private func makeEvent(startDate: (hour: Int, minute: Int), endDate: (hour: Int, minute: Int)) -> Event {
        Event(
            startDate: makeDate(hour: startDate.hour, minute: startDate.minute),
            endDate: makeDate(hour: endDate.hour, minute: endDate.minute)
        )
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
