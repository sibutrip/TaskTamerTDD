//
//  Event.swift
//  TaskTamerTDD
//
//  Created by Cory Tripathy on 12/18/23.
//

import Foundation

struct Event: Identifiable, Equatable {
    var startDate: Date
    var endDate: Date
    let id = UUID().uuidString
}
