//
//  EventService.swift
//  TaskTamerTDD
//
//  Created by Cory Tripathy on 12/18/23.
//

import Foundation

class EventService<EventType: Event> {
    let store: EventStore
    
    enum EventServiceError: Error {
        case couldNotRemoveEvent, eventNotInDatabase, couldNotSaveEvent, couldNotUpdateEvent, scheduleIsBusyAtSelectedDate
    }
    
    init(store: EventStore) {
        self.store = store
    }
    
    //TODO: rename to fetch tasks
    func fetchEvents(between startDate: Date, and endDate: Date) -> [TaskItem] {
        let fetchedEvents = store.events(between: startDate, and: endDate)
        
        let matchingEvents = fetchedEvents.filter {
            ($0.endDate > startDate && $0.endDate < endDate) || ($0.startDate < endDate && $0.startDate > startDate)
        }
        return matchingEvents.map { TaskItem(fromEvent: $0) }
    }
    
    func removeEvent(matching id: TaskItem.ID) throws {
        guard let event = store.event(withIdentifier: id) else {
            throw EventServiceError.eventNotInDatabase
        }
        do { try store.remove(event) }
        catch { throw EventServiceError.couldNotRemoveEvent }
    }
    
    func update(_ task: TaskItem) throws -> TaskItem {
        guard var fetchedEvent = store.event(withIdentifier: task.id) else {
            throw EventServiceError.couldNotUpdateEvent
        }
        
        do {
            try store.remove(fetchedEvent)
            fetchedEvent.startDate = task.startDate
            fetchedEvent.endDate = task.endDate
            try store.save(fetchedEvent)
        }
        catch { throw EventServiceError.couldNotUpdateEvent }
        
        return TaskItem(fromEvent: fetchedEvent)
    }
    
    func schedule(_ task: TaskItem) throws -> TaskItem {
        let existingEventsAtSelectedTime = fetchEvents(between: task.startDate, and: task.endDate)
        if !existingEventsAtSelectedTime.isEmpty {
            throw EventServiceError.scheduleIsBusyAtSelectedDate
        }
        
        var event = EventType()
        event.startDate = task.startDate
        event.endDate = task.endDate
        
        do {
            try store.save(event)
            return TaskItem(fromEvent: event)
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
