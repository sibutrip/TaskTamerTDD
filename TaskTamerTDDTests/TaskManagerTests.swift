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
        guard var taskToSort = tasks.first(where: { $0.id == task.id }) else {
            return
        }
        taskToSort.sortStatus = sortStatus
        var tasks = tasks.filter { $0.id != task.id }
        tasks.append(taskToSort)
        self.tasks = tasks
    }
}

final class TaskManagerTests: XCTestCase {
    func test_sort_changesSortStatusToNewStatus() {
        let sut = makeSUT(withTasks: existingTasks())
        let taskToSort = sut.tasks.first!
        sut.sort(taskToSort, to: .afternoon)
        var sortedTask = taskToSort
        sortedTask.sortStatus = .afternoon
        XCTAssertTrue(sut.tasks.contains(where: { $0 == sortedTask}))
    }
    
    // MARK: Helper Methods
    
    private func existingTasks() -> [TaskItem] {
        return [
            TaskItem(title: "Write tests for TaskTamer", startDate: makeDate(hour: 8, minute: 30), endDate: makeDate(hour: 9, minute: 0)),
            TaskItem(title: "Redesign Coffeecule", startDate: makeDate(hour: 9, minute: 30), endDate: makeDate(hour: 9, minute: 45))
        ]
    }
    
    private func makeSUT(withTasks tasks: [TaskItem]) -> TaskManager {
        let sut = TaskManager()
        sut.tasks = tasks
        return sut
    }
    
    private func makeDate(hour: Int, minute: Int) -> Date {
        Calendar.autoupdatingCurrent.date(bySettingHour: hour, minute: minute, second: 0, of: Date())!
    }
}
