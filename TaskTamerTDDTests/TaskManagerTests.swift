//
//  TaskManagerTests.swift
//  TaskTamerTDDTests
//
//  Created by Cory Tripathy on 12/10/23.
//

import Foundation
import XCTest
@testable import TaskTamerTDD

class TaskManager {
    var tasks = [TaskItem]()
    func sort(_ task: TaskItem, to sortStatus: SortStatus) { 
        let taskToSort = tasks.first(where: {$0.id == task.id})
    }
}

//final class TaskManagerTests: XCTestCase {
//    func test_sort_changesSortStatusToNewStatus() {
//        let sut = makeSUT(withTasks: existingTasks())
//        let taskToSort = sut.tasks.first!
//        sut.sort(taskToSort, to: .afternoon)
//        let sortedTask = sut.tasks.first!
//        XCTAssertEqual(sortedTask.sortStatus, .afternoon)
//    }
//    
//    // MARK: Helper Methods
//    
//    private func existingTasks() -> [TaskItem] {
//        return [
//            TaskItem(title: "Write tests for TaskTamer"),
//            TaskItem(title: "Redesign Coffeecule")
//        ]
//    }
//    
//    private func makeSUT(withTasks tasks: [TaskItem]) -> TaskManager {
//        let sut = TaskManager()
//        sut.tasks = tasks
//        return sut
//    }
//}
