import Foundation
import Combine

@MainActor
final class TaskExecutionService {
    private let taskService: TaskService
    private let gatewayService: GatewayService
    private let onTaskCompleted: (TaskItem) -> Void

    private var cancellables = Set<AnyCancellable>()
    private var orchestratorTask: Task<Void, Never>?
    private var activeRuns: Set<UUID> = []
    private var activeAgents: Set<String> = []
    private var nextEligibleAt: [UUID: Date] = [:]
    private var isTickRunning = false

    init(
        taskService: TaskService,
        gatewayService: GatewayService,
        onTaskCompleted: @escaping (TaskItem) -> Void
    ) {
        self.taskService = taskService
        self.gatewayService = gatewayService
        self.onTaskCompleted = onTaskCompleted
        subscribe()
        startLoop()
    }

    deinit {
        orchestratorTask?.cancel()
    }

    func handleTaskMovedToInProgress(_ task: TaskItem) {
        Task { [weak self] in
            await self?.startTaskIfNeeded(taskId: task.id)
        }
    }

    private func subscribe() {
        taskService.$tasks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.runTick()
                }
            }
            .store(in: &cancellables)

        taskService.$isExecutionPaused
            .receive(on: DispatchQueue.main)
            .sink { [weak self] paused in
                guard let self else { return }
                if !paused {
                    Task { [weak self] in
                        await self?.runTick()
                    }
                }
            }
            .store(in: &cancellables)
    }

    private func startLoop() {
        orchestratorTask?.cancel()
        orchestratorTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4))
                await self.runTick()
            }
        }
    }

    private func runTick() async {
        guard !isTickRunning else { return }
        guard gatewayService.isConnected else { return }
        guard !taskService.isExecutionPaused else { return }
        isTickRunning = true
        defer { isTickRunning = false }

        // Ready tasks are considered execution candidates; enqueue automatically.
        let ready = taskService.tasks.filter { !$0.isArchived && $0.status == .scheduled }
        for task in ready {
            taskService.moveTask(task.id, to: .queued)
            taskService.appendTaskEvidence(task.id, text: "Auto-queued at \(Date().shortString)")
        }

        let now = Date()
        var reservedAgents = activeAgents

        // Resume any in-progress tasks that are not actively running.
        let inProgress = taskService.tasksForStatus(.inProgress)
        for task in inProgress {
            guard isEligible(task.id, now: now) else { continue }
            guard let agent = normalizedAgent(task.assignedAgent) else { continue }
            guard !reservedAgents.contains(agent) else { continue }
            reservedAgents.insert(agent)
            Task { [weak self] in
                await self?.startTaskIfNeeded(taskId: task.id)
            }
        }

        // Start queued tasks when agent is free.
        let queued = taskService.tasksForStatus(.queued).sorted(by: queuePrioritySort)
        for task in queued {
            guard isEligible(task.id, now: now) else { continue }
            guard let agent = normalizedAgent(task.assignedAgent) else { continue }
            guard !reservedAgents.contains(agent) else { continue }
            reservedAgents.insert(agent)
            taskService.moveTask(task.id, to: .inProgress)
            taskService.appendTaskEvidence(task.id, text: "Dequeued to In Progress at \(Date().shortString)")
            Task { [weak self] in
                await self?.startTaskIfNeeded(taskId: task.id)
            }
        }
    }

    private func startTaskIfNeeded(taskId: UUID) async {
        guard !taskService.isExecutionPaused else { return }
        guard !activeRuns.contains(taskId) else { return }
        guard let task = taskService.tasks.first(where: { $0.id == taskId }) else { return }
        guard !task.isArchived, task.status == .inProgress else { return }
        guard let agent = normalizedAgent(task.assignedAgent) else { return }
        guard !activeAgents.contains(agent) else { return }

        activeRuns.insert(task.id)
        activeAgents.insert(agent)
        defer {
            activeRuns.remove(task.id)
            activeAgents.remove(agent)
        }

        let sessionKey = task.executionSessionKey?.isEmpty == false
            ? (task.executionSessionKey ?? "")
            : "agent:\(agent):task:\(task.id.uuidString.lowercased())"
        taskService.mutateTask(task.id) { mutable in
            mutable.executionSessionKey = sessionKey
        }
        taskService.appendTaskEvidence(task.id, text: "Kickoff sent to \(agent) at \(Date().shortString)")

        let projectLine = (task.projectName?.isEmpty == false) ? "Project: \(task.projectName!)" : "Project: Unspecified"
        let details = task.description?.trimmingCharacters(in: .whitespacesAndNewlines)
        let detailLine = (details?.isEmpty == false) ? "Task details: \(details!)" : "Task details: none"
        let kickoff = """
        [task-start]
        \(projectLine)
        Task ID: \(task.id.uuidString)
        Task: \(task.title)
        \(detailLine)

        Continue from existing progress if present.
        End with exactly one marker line:
        [task-complete] or [task-continue] or [task-blocked]
        """

        do {
            let response = try await gatewayService.sendAgentMessage(
                agentId: agent,
                message: kickoff,
                sessionKey: sessionKey,
                thinkingEnabled: true
            )
            let text = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                taskService.appendTaskEvidence(task.id, text: "Final response:\n\(text)")
            }

            let outcome = parseOutcome(text)
            switch outcome {
            case .complete:
                taskService.moveTask(task.id, to: .done)
                if let done = taskService.tasks.first(where: { $0.id == task.id }) {
                    onTaskCompleted(done)
                }
            case .continueWork:
                taskService.moveTask(task.id, to: .queued)
                setCooldown(task.id, seconds: 120)
            case .blocked:
                taskService.moveTask(task.id, to: .queued)
                setCooldown(task.id, seconds: 60 * 60)
            }
        } catch {
            let errorText = error.localizedDescription
            taskService.appendTaskEvidence(task.id, text: "Run error: \(errorText)")
            taskService.moveTask(task.id, to: .queued)
            let lower = errorText.lowercased()
            if lower.contains("rate limited") || lower.contains("429") || lower.contains("too many requests") || lower.contains("quota") {
                setCooldown(task.id, seconds: 60 * 60)
            } else {
                setCooldown(task.id, seconds: 10 * 60)
            }
        }
    }

    private enum Outcome {
        case complete
        case continueWork
        case blocked
    }

    private func parseOutcome(_ text: String) -> Outcome {
        let lower = text.lowercased()
        if lower.contains("[task-complete]") { return .complete }
        if lower.contains("[task-blocked]") { return .blocked }
        if lower.contains("[task-continue]") { return .continueWork }
        return .continueWork
    }

    private func normalizedAgent(_ value: String?) -> String? {
        guard let value else { return nil }
        let token = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return token.isEmpty ? nil : token
    }

    private func queuePrioritySort(_ lhs: TaskItem, _ rhs: TaskItem) -> Bool {
        let lRank = priorityRank(lhs.priority)
        let rRank = priorityRank(rhs.priority)
        if lRank != rRank { return lRank < rRank }
        if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt < rhs.updatedAt }
        return lhs.createdAt < rhs.createdAt
    }

    private func priorityRank(_ priority: TaskPriority) -> Int {
        switch priority {
        case .urgent: return 0
        case .high: return 1
        case .medium: return 2
        case .low: return 3
        }
    }

    private func isEligible(_ taskId: UUID, now: Date) -> Bool {
        if let date = nextEligibleAt[taskId] {
            return now >= date
        }
        return true
    }

    private func setCooldown(_ taskId: UUID, seconds: TimeInterval) {
        nextEligibleAt[taskId] = Date().addingTimeInterval(seconds)
    }
}
