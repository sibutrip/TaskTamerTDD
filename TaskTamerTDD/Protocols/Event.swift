//
//  Event.swift
//  TaskTamerTDD
//
//  Created by Cory Tripathy on 12/18/23.
//

import Foundation

protocol Event {
    var eventIdentifier: String! { get }
    var calendar: UserCalendar! { get set }
    var title: String! { get set }
    var startDate: Date! { get set }
    var endDate: Date! { get set }
    func addAlarm(_ alarm: Alarm)
    init()
}
