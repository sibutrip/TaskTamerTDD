//
//  Alarm.swift
//  TaskTamerTDD
//
//  Created by Cory Tripathy on 12/18/23.
//

import Foundation

protocol Alarm {
    var absoluteDate: Date? { get set }
    init(absoluteDate: Date)
}
