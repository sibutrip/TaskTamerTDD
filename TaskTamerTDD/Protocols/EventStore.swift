//
//  EventStore.swift
//  TaskTamerTDD
//
//  Created by Cory Tripathy on 12/18/23.
//

import Foundation

protocol EventStore {
    
    /// to use with Event kit, use the predicateForEvents(withStart:end:calendars:) method to get a NSPredicate then query for events
    func events(between startDate: Date, and endDate: Date) -> [Event]
    func connect() -> Bool
    func remove(_ event: Event) throws
    func event(withIdentifier identifier: String) -> Event?
    func save(_ event: Event) throws
}
