//
//  EventService.swift
//  TaskTamerTDD
//
//  Created by Cory Tripathy on 12/18/23.
//

import Foundation

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
    
    func freeTimeBetween(startDate: Date, endDate: Date) -> [(start: Date, end: Date)] {
        var currentFreeStartTime = startDate
        let existingEvents = fetchEvents(between: startDate, and: endDate)
            .sorted { $0.startDate < $1.startDate}
        
        var freeTimes = [(start: Date, end: Date)]()
        existingEvents.forEach { existingEvent in
            if currentFreeStartTime < existingEvent.startDate {
                freeTimes.append((currentFreeStartTime, existingEvent.startDate))
            }
            currentFreeStartTime = max(currentFreeStartTime, existingEvent.endDate)
        }
        if currentFreeStartTime < endDate {
            freeTimes.append((currentFreeStartTime, endDate))
        }
        
        return freeTimes
    }
}
