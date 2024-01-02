//
//  EventFetcherTests.swift
//  EventFetchingTDDFunTests
//
//  Created by Tom Phillips on 11/6/23.
//

import XCTest
@testable import TaskTamerTDD

final class EventServiceTests: XCTestCase {
    typealias EventServiceError = EventService<MockEvent>.EventServiceError

    func test_fetchEvents_returnsEmptyIfNoDatesScheduledInGivenRange() {
        let sut = makeSUT()
        
        let startDate = makeDate(hour: 8, minute: 0)
        let endDate = makeDate(hour: 12, minute: 0)
        let scheduledEvents = sut.fetchEvents(between: startDate, and: endDate)
        
        XCTAssertEqual(scheduledEvents, [TaskItem]())
    }
    
    func test_fetchEvents_returnsAllScheduledEventsIfAllEventsAreInTheGivenDateRange() {
        let allScheduledEvents = allScheduledEvents()
        let sut = makeSUT(withEvents: allScheduledEvents)
        
        let startDate = makeDate(hour: 8, minute: 0)
        let endDate = makeDate(hour: 12, minute: 0)
        let scheduledTasks = sut.fetchEvents(between: startDate, and: endDate)
        
        assertTasksAndEventsAreEqual(tasks: scheduledTasks, events: allScheduledEvents)
    }
    
    func test_fetchEvents_returnsOnlyScheduledEventsInTheGivenDateRange() {
        let allScheduledEvents = allScheduledEvents()
        let sut = makeSUT(withEvents: allScheduledEvents)

        let startDate = makeDate(hour: 6, minute: 0)
        let endDate = makeDate(hour: 9, minute: 0)
        let scheduledTasks = sut.fetchEvents(between: startDate, and: endDate)
        
        assertTasksAndEventsAreEqual(tasks: scheduledTasks, events: [allScheduledEvents[0]])
    }
    
    func test_remove_removesEventFromEventStoreMatchingGivenId() throws {
        let originalScheduledEvents = allScheduledEvents()
        let taskToRemove = TaskItem(title: "Test", startDate: makeDate(hour: 8, minute: 0), endDate: makeDate(hour: 9, minute: 0))
        let eventToRemove = MockEvent()
        eventToRemove.startDate = taskToRemove.startDate
        eventToRemove.endDate = taskToRemove.endDate
        let allScheduledEvents = originalScheduledEvents + [eventToRemove]
        let idToDelete = eventToRemove.eventIdentifier!
        let sut = makeSUT(withEvents: allScheduledEvents)

        try sut.removeEvent(matching: idToDelete)
        let allTasksAfterRemoval = sut.fetchEvents(between: .distantPast, and: .distantFuture)
        
        assertTasksAndEventsAreEqual(tasks: allTasksAfterRemoval, events: originalScheduledEvents)
    }
    
    func test_remove_throwsCannotRemoveEventIfNoConnectionToAPI() throws {
        let originalScheduledEvents = allScheduledEvents()
        let eventToRemove = MockEvent()
        eventToRemove.startDate = makeDate(hour: 8, minute: 0)
        eventToRemove.endDate = makeDate(hour: 9, minute: 0)
        let eventId = eventToRemove.eventIdentifier!
        let allScheduledEvents = originalScheduledEvents + [eventToRemove]
        let sut = makeSUT(withEvents: allScheduledEvents, willConnect: false)
        
        assertDoesThrow(test: {
            try sut.removeEvent(matching: eventId)
        }, throws: .couldNotRemoveEvent)
    }
    
    func test_remove_throwsIfEventNotInDatabase() throws {
        let scheduledEvents = allScheduledEvents()
        let eventToRemove = TaskItem(title: "Test", startDate: makeDate(hour: 8, minute: 0), endDate: makeDate(hour: 9, minute: 0))
        let sut = makeSUT(withEvents: scheduledEvents, willConnect: true)
        
        assertDoesThrow(test: {
            try sut.removeEvent(matching: eventToRemove.id)
        }, throws: .eventNotInDatabase)
    }
    
    func test_update_returnsUpdatedEventFromStoreOnSuccess() throws {
        let scheduledEvents = allScheduledEvents()
        let eventToReschedule = scheduledEvents[0]
        let sut = makeSUT(withEvents: scheduledEvents)
        
        eventToReschedule.startDate = makeDate(hour: 6, minute: 15)
        eventToReschedule.endDate = makeDate(hour: 10, minute: 15)
        let taskToReschedule = TaskItem(fromEvent: eventToReschedule)
        let updatedEvent = try sut.update(taskToReschedule)
        
        XCTAssertEqual(taskToReschedule, updatedEvent)
     }
    
    func test_update_throwsCouldNotUpdateEventIfNoDatabaseConnection() throws {
        let scheduledEvents = allScheduledEvents()
        let sut = makeSUT(withEvents: scheduledEvents, willConnect: false)
        
        let eventToReschedule = scheduledEvents[0]
        eventToReschedule.startDate = makeDate(hour: 6, minute: 15)
        eventToReschedule.endDate = makeDate(hour: 10, minute: 15)
        let taskToReschedule = TaskItem(fromEvent: eventToReschedule)
        
        assertDoesThrow(test: {
            _ = try sut.update(taskToReschedule)
        }, throws: .couldNotUpdateEvent)
     }
    
    func test_update_throwsCouldNotUpdateEventIfEventNotInDatabase() throws {
        let scheduledEvents = allScheduledEvents()
        let sut = makeSUT(withEvents: scheduledEvents, willConnect: false)
        
        var eventToReschedule = TaskItem(title: "Test", startDate: Date(), endDate: Date())
        eventToReschedule.startDate = makeDate(hour: 6, minute: 15)
        eventToReschedule.endDate = makeDate(hour: 10, minute: 15)
        
        assertDoesThrow(test: {
            _ = try sut.update(eventToReschedule)
        }, throws: .couldNotUpdateEvent)
     }
    
    func test_schedule_addsEventToStoreIfCalendarIsFree() throws {
        let sut = makeSUT()
        let event = TaskItem(title: "Test", startDate: makeDate(hour: 9, minute: 0), endDate: makeDate(hour: 9, minute: 30))
        
        let scheduledEvent = try sut.schedule(event)
        
        XCTAssertEqual(scheduledEvent.startDate, event.startDate)
        XCTAssertEqual(scheduledEvent.endDate, event.endDate)
    }
    
    func test_schedule_throwsIfOverlapsWithExistingEvent() {
        let sut = makeSUT(withEvents: allScheduledEvents())
        let event = TaskItem(title: "Test", startDate: makeDate(hour: 8, minute: 45), endDate: makeDate(hour: 9, minute: 15))
        
        assertDoesThrow(test: {
            _ = try sut.schedule(event)
        }, throws: .scheduleIsBusyAtSelectedDate)
    }
    
    func test_freeTimeBetween_retreivesFreeTimeBetweenStartAndEndDates() {
        let sut = makeSUT(withEvents: allScheduledEvents())
        let startTime = makeDate(hour: 7, minute: 0)
        let endTime = makeDate(hour: 10, minute: 30)
        let expectedFreeTime: [(start: Date, end: Date)] = [
            (start: makeDate(hour: 7, minute: 0), end: makeDate(hour: 8, minute: 0)),
            (start: makeDate(hour: 8, minute: 30), end: makeDate(hour: 9, minute: 0)),
            (start: makeDate(hour: 9, minute: 15), end: makeDate(hour: 10, minute: 30))
        ]
        
        let freeTime = sut.freeTimeBetween(startDate: startTime, endDate: endTime)
        
        let formattedFreeTime = freeTime.flatMap { [$0.start, $0.end] }
        let formattedExpectedFreeTime = expectedFreeTime.flatMap { [$0.start, $0.end] }
        
        XCTAssertEqual(formattedFreeTime, formattedExpectedFreeTime)
    }
    
    func test_freeTimeBetween_retreivesFreeTimeBetweenStartAndEndDatesIfEndDateIsBetweenFirstEventStartAndEndTime() {
        let sut = makeSUT(withEvents: allScheduledEvents())
        let startTime = makeDate(hour: 8, minute: 15)
        let endTime = makeDate(hour: 10, minute: 30)
        let expectedFreeTime: [(start: Date, end: Date)] = [
            (start: makeDate(hour: 8, minute: 30), end: makeDate(hour: 9, minute: 0)),
            (start: makeDate(hour: 9, minute: 15), end: makeDate(hour: 10, minute: 30))
        ]
        
        let freeTime = sut.freeTimeBetween(startDate: startTime, endDate: endTime)

        let formattedFreeTime = freeTime.flatMap { [$0.start, $0.end] }
        let formattedExpectedFreeTime = expectedFreeTime.flatMap { [$0.start, $0.end] }
        XCTAssertEqual(formattedFreeTime, formattedExpectedFreeTime)
    }
    
    func test_freeTimeBetween_retreivesFreeTimeBetweenStartAndEndDatesIfEndDateIsBetweenLastEventStartAndEndTime() {
        let sut = makeSUT(withEvents: allScheduledEvents())
        let startTime = makeDate(hour: 7, minute: 0)
        let endTime = makeDate(hour: 9, minute: 10)
        let expectedFreeTime: [(start: Date, end: Date)] = [
            (start: makeDate(hour: 7, minute: 0), end: makeDate(hour: 8, minute: 0)),
            (start: makeDate(hour: 8, minute: 30), end: makeDate(hour: 9, minute: 0))
        ]
        
        let freeTime = sut.freeTimeBetween(startDate: startTime, endDate: endTime)

        let formattedFreeTime = freeTime.flatMap { [$0.start, $0.end] }
        let formattedExpectedFreeTime = expectedFreeTime.flatMap { [$0.start, $0.end] }
        XCTAssertEqual(formattedFreeTime, formattedExpectedFreeTime)
    }
    
    // MARK: Helper Methods
    private func makeSUT(withEvents events: [MockEvent] = [], willConnect: Bool = true) -> EventService<MockEvent> {
        let store = MockEventStore(scheduledEvents: events, willConnect: willConnect)
        return EventService<MockEvent>(store: store)
    }
    private func makeEvent(startDate: (hour: Int, minute: Int), endDate: (hour: Int, minute: Int)) -> MockEvent {
        let event = MockEvent()
        event.title = "Test"
        event.startDate = makeDate(hour: startDate.hour, minute: startDate.minute)
        event.endDate = makeDate(hour: endDate.hour, minute: endDate.minute)
        return event
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
    
    private func allScheduledEvents() -> [MockEvent] {
        let firstEvent = makeEvent(startDate: (hour: 8, minute: 0), endDate: (hour: 8, minute: 30))
        
        let secondEvent = makeEvent(startDate: (hour: 9, minute: 0), endDate: (hour: 9, minute: 15))
        
        
        return [firstEvent, secondEvent]
    }
    
    private func assertTasksAndEventsAreEqual(tasks: [TaskItem], events: [MockEvent]) {
        let tasksFromEvents = events.map { TaskItem(fromEvent: $0) }
        for task in tasks {
            if !tasksFromEvents.contains(where: {$0 == task}) {
                XCTFail("tasks and events are not equal")
                return
            }
        }
        XCTAssert(true)
    }
}
