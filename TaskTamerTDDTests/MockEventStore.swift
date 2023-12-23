//
//  MockEventStore.swift
//  TaskTamerTDDTests
//
//  Created by Cory Tripathy on 12/18/23.
//

import Foundation
@testable import TaskTamerTDD

class MockEventStore: EventStore {
    typealias MockEvent = Event
    
    var defaultCalendarForNewEvents: UserCalendar?
    
    func remove(_ event: MockEvent) throws {
        if !willConnect {
            throw NSError(domain: "no connection", code: 0)
        }
        scheduledEvents.removeAll { $0.eventIdentifier == event.eventIdentifier }
    }
    
    func event(withIdentifier identifier: String) -> MockEvent? {
        scheduledEvents.first { event in
            event.eventIdentifier == identifier
        }
    }
    
    func connect() -> Bool {
        return willConnect
    }
    
    private var scheduledEvents: [MockEvent]
    private var willConnect: Bool = true
    
    init(scheduledEvents: [MockEvent] = [], willConnect: Bool = true) {
        self.scheduledEvents = scheduledEvents
        self.willConnect = willConnect
    }
    
    func events(between startDate: Date, and endDate: Date) -> [MockEvent] {
        return scheduledEvents.filter { event in
            event.startDate > startDate && event.startDate < endDate || event.endDate > startDate && event.endDate < endDate
        }
    }
    
    func save(_ event: MockEvent) throws {
        scheduledEvents.append(event)
    }
}
