//
//  MockEvent.swift
//  TaskTamerTDDTests
//
//  Created by Cory Tripathy on 12/23/23.
//

import Foundation
@testable import TaskTamerTDD

class MockEvent: Event {
    var eventIdentifier: String!
    
    var calendar: TaskTamerTDD.UserCalendar!
    
    var title: String!
    
    var startDate: Date!
    
    var endDate: Date!
    
    func addAlarm(_ alarm: TaskTamerTDD.Alarm) { }
    
    required init() {
        eventIdentifier = UUID().uuidString
    }
}
