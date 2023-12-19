//
//  EventFetcherTests.swift
//  EventFetchingTDDFunTests
//
//  Created by Tom Phillips on 11/6/23.
//

import XCTest
import EventKit

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
    
    func test_freeTimeBetween_retreivesFreeTimeBetweenStartAndEndDates() {
        let store = MockEventStore(scheduledEvents: allScheduledEvents())
        let sut = EventService(store: store)
        let startTime = makeDate(hour: 7, minute: 0)
        let endTime = makeDate(hour: 10, minute: 30)
        let freeTime = sut.freeTimeBetween(startDate: startTime, endDate: endTime)
        let expectedFreeTime: [(start: Date, end: Date)] = [
            (start: makeDate(hour: 7, minute: 0), end: makeDate(hour: 8, minute: 0)),
            (start: makeDate(hour: 8, minute: 30), end: makeDate(hour: 9, minute: 0)),
            (start: makeDate(hour: 9, minute: 15), end: makeDate(hour: 10, minute: 30))
        ]
        let formattedFreeTime = freeTime.flatMap { [$0.start, $0.end] }
        let formattedExpectedFreeTime = expectedFreeTime.flatMap { [$0.start, $0.end] }
        XCTAssertEqual(formattedFreeTime, formattedExpectedFreeTime)
    }
    
    func test_freeTimeBetween_retreivesFreeTimeBetweenStartAndEndDatesIfEndDateIsBetweenFirstEventStartAndEndTime() {
        let store = MockEventStore(scheduledEvents: allScheduledEvents())
        let sut = EventService(store: store)
        let startTime = makeDate(hour: 8, minute: 15)
        let endTime = makeDate(hour: 10, minute: 30)
        let freeTime = sut.freeTimeBetween(startDate: startTime, endDate: endTime)
        let expectedFreeTime: [(start: Date, end: Date)] = [
            (start: makeDate(hour: 8, minute: 30), end: makeDate(hour: 9, minute: 0)),
            (start: makeDate(hour: 9, minute: 15), end: makeDate(hour: 10, minute: 30))
        ]
        let formattedFreeTime = freeTime.flatMap { [$0.start, $0.end] }
        let formattedExpectedFreeTime = expectedFreeTime.flatMap { [$0.start, $0.end] }
        XCTAssertEqual(formattedFreeTime, formattedExpectedFreeTime)
    }
    
    func test_freeTimeBetween_retreivesFreeTimeBetweenStartAndEndDatesIfEndDateIsBetweenLastEventStartAndEndTime() {
        let store = MockEventStore(scheduledEvents: allScheduledEvents())
        let sut = EventService(store: store)
        let startTime = makeDate(hour: 7, minute: 0)
        let endTime = makeDate(hour: 9, minute: 10)
        let freeTime = sut.freeTimeBetween(startDate: startTime, endDate: endTime)
        let expectedFreeTime: [(start: Date, end: Date)] = [
            (start: makeDate(hour: 7, minute: 0), end: makeDate(hour: 8, minute: 0)),
            (start: makeDate(hour: 8, minute: 30), end: makeDate(hour: 9, minute: 0))
        ]
        let formattedFreeTime = freeTime.flatMap { [$0.start, $0.end] }
        let formattedExpectedFreeTime = expectedFreeTime.flatMap { [$0.start, $0.end] }
        XCTAssertEqual(formattedFreeTime, formattedExpectedFreeTime)
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
