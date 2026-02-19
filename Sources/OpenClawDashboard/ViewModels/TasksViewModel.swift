import SwiftUI
import Combine

@MainActor
class TasksViewModel: ObservableObject {
    @Published var isEditing = false
    @Published var editingTask: TaskItem?
    @Published var showingNewTask = false

    private let taskService: TaskService
    private var cancellables = Set<AnyCancellable>()

    init(taskService: TaskService) {
        self.taskService = taskService
        taskService.$tasks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        taskService.$isExecutionPaused
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    var tasks: [TaskItem] {
        taskService.tasks
    }

    func tasksFor(_ status: TaskStatus) -> [TaskItem] {
        taskService.tasksForStatus(status)
    }

    func countFor(_ status: TaskStatus) -> Int {
        tasksFor(status).count
    }

    var isExecutionPaused: Bool {
        taskService.isExecutionPaused
    }

    func toggleExecutionPaused() {
        taskService.toggleExecutionPaused()
        objectWillChange.send()
    }

    // MARK: - CRUD

    func createTask(
        title: String,
        description: String?,
        assignedAgent: String?,
        priority: TaskPriority,
        scheduledFor: Date?,
        projectId: String? = nil,
        projectName: String? = nil,
        projectColorHex: String? = nil
    ) {
        _ = taskService.createTask(
            title: title,
            description: description,
            assignedAgent: assignedAgent,
            status: .scheduled,
            priority: priority,
            scheduledFor: scheduledFor,
            projectId: projectId,
            projectName: projectName,
            projectColorHex: projectColorHex
        )
        objectWillChange.send()
    }

    func updateTask(_ task: TaskItem) {
        taskService.updateTask(task)
        objectWillChange.send()
    }

    func deleteTask(_ taskId: UUID) {
        taskService.deleteTask(taskId)
        objectWillChange.send()
    }

    func moveTask(_ taskId: UUID, to status: TaskStatus) {
        taskService.moveTask(taskId, to: status)
        objectWillChange.send()
    }

    func handleDrop(of tasks: [TaskItem], to status: TaskStatus) -> Bool {
        for task in tasks {
            moveTask(task.id, to: status)
        }
        return !tasks.isEmpty
    }

    // MARK: - Edit Sheet

    func startEditing(_ task: TaskItem) {
        editingTask = task
        isEditing = true
    }

    func startNewTask() {
        editingTask = nil
        showingNewTask = true
    }
}
