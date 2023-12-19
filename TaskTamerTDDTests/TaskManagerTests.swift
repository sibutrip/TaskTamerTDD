//
//  TaskManagerTests.swift
//  TaskTamerTDDTests
//
//  Created by Cory Tripathy on 12/10/23.
//

import Foundation
import XCTest

class TaskManager {
    var tasks = [TaskItem]()
    func sort(_ task: TaskItem) { }
}

enum SortStatus {
    case unsorted, morning, afternoon, evening, skip1, skip3, skip7
}

struct TaskItem: Identifiable {
    let id = UUID()
    let title: String
    var sortStatus: SortStatus
}

final class TaskManagerTests: XCTestCase {
    func test_sort_changesSortStatusToNewStatus() {
        let sut = makeSUT(withTasks: existingTasks())
        let taskToSort = sut.tasks.first!
        sut.sort(<#T##task: TaskItem##TaskItem#>)
    }
    
    // MARK: Helper Methods
    
    private func existingTasks() -> [TaskItem] {
        return [
            TaskItem(title: "Write tests for TaskTamer"),
            TaskItem(title: "Redesign Coffeecule")
        ]
    }
    
    private func makeSUT(withTasks tasks: [TaskItem]) -> TaskManager {
        let sut = TaskManager()
        let sut.tasks = tasks
        return sut
    }
}
