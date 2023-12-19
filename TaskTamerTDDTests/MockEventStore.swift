//
//  MockEventStore.swift
//  TaskTamerTDDTests
//
//  Created by Cory Tripathy on 12/18/23.
//

import Foundation
@testable import TaskTamerTDD

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
        return scheduledEvents.filter { event in
            event.startDate > startDate && event.startDate < endDate || event.endDate > startDate && event.endDate < endDate
        }
    }
    
    func save(_ event: Event) throws {
        scheduledEvents.append(event)
    }
}
