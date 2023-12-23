//
//  Event.swift
//  TaskTamerTDD
//
//  Created by Cory Tripathy on 12/18/23.
//

import Foundation

struct TaskItem: Identifiable, Equatable {
    let id: String
    let title: String
    var startDate: Date
    var endDate: Date
    var sortStatus: SortStatus = .unsorted
    init(title: String, startDate: Date, endDate: Date) {
        id = UUID().uuidString
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
    }
    init(fromEvent event: Event) {
        id = event.eventIdentifier
        title = event.title
        startDate = event.startDate
        endDate = event.endDate
    }
}

enum SortStatus {
    case unsorted, morning, afternoon, evening, skip1, skip3, skip7
}
