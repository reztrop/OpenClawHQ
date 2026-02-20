import XCTest
@testable import OpenClawDashboard

@MainActor
final class TaskServiceSingleActiveTaskTests: XCTestCase {
    func testMoveTaskToInProgressDemotesExistingTaskForSameAgent() {
        let paths = makeTempPaths(testName: #function)
        defer { cleanup(paths.dir) }

        let service = TaskService(filePath: paths.tasksFile, stateFilePath: paths.stateFile)
        service.tasks = []

        let first = service.createTask(title: "First", assignedAgent: "Matrix", status: .queued)
        let second = service.createTask(title: "Second", assignedAgent: "matrix", status: .queued)

        service.moveTask(first.id, to: .inProgress)
        service.moveTask(second.id, to: .inProgress)

        let firstStatus = service.tasks.first(where: { $0.id == first.id })?.status
        let secondStatus = service.tasks.first(where: { $0.id == second.id })?.status

        XCTAssertEqual(firstStatus, .queued)
        XCTAssertEqual(secondStatus, .inProgress)
        XCTAssertEqual(service.tasks.filter { $0.status == .inProgress && $0.assignedAgent?.lowercased() == "matrix" }.count, 1)
    }

    func testLoadTasksRepairsDuplicateInProgressTasksPerAgent() throws {
        let paths = makeTempPaths(testName: #function)
        defer { cleanup(paths.dir) }

        let now = Date()
        let taskA = TaskItem(title: "Older", assignedAgent: "Prism", status: .inProgress, updatedAt: now.addingTimeInterval(-30))
        let taskB = TaskItem(title: "Newer", assignedAgent: "prism", status: .inProgress, updatedAt: now)
        let taskC = TaskItem(title: "Other", assignedAgent: "Atlas", status: .inProgress, updatedAt: now)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode([taskA, taskB, taskC])
        try data.write(to: URL(fileURLWithPath: paths.tasksFile), options: .atomic)

        let service = TaskService(filePath: paths.tasksFile, stateFilePath: paths.stateFile)
        let prismTasks = service.tasks.filter { $0.assignedAgent?.lowercased() == "prism" }

        XCTAssertEqual(prismTasks.filter { $0.status == .inProgress }.count, 1)
        XCTAssertEqual(prismTasks.first(where: { $0.title == "Newer" })?.status, .inProgress)
        XCTAssertEqual(prismTasks.first(where: { $0.title == "Older" })?.status, .queued)
    }

    private func makeTempPaths(testName: String) -> (dir: String, tasksFile: String, stateFile: String) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenClawDashboardTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let tasksFile = root.appendingPathComponent("tasks-\(testName).json").path
        let stateFile = root.appendingPathComponent("state-\(testName).json").path
        return (root.path, tasksFile, stateFile)
    }

    private func cleanup(_ dir: String) {
        try? FileManager.default.removeItem(atPath: dir)
    }
}
