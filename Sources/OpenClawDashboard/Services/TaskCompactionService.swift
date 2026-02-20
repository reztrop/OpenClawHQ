import Foundation

@MainActor
final class TaskCompactionService {
    private struct CompactionState: Codable {
        var lastCompactionAt: Date?
    }

    private let taskService: TaskService
    private let gatewayService: GatewayService
    private let reportsDirectoryPath: String
    private let stateFilePath: String
    private let now: () -> Date

    private var lastCompactionAt: Date?
    private let compactionCooldown: TimeInterval = 15 * 60

    init(
        taskService: TaskService,
        gatewayService: GatewayService,
        reportsDirectoryPath: String = Constants.taskInterventionReportsDirectory,
        stateFilePath: String = Constants.taskCompactionStateFilePath,
        now: @escaping () -> Date = Date.init
    ) {
        self.taskService = taskService
        self.gatewayService = gatewayService
        self.reportsDirectoryPath = reportsDirectoryPath
        self.stateFilePath = stateFilePath
        self.now = now
        loadState()
    }

    func evaluateScopeCompaction(tasks: [TaskItem]) async -> String? {
        let activeCount = tasks.filter {
            !$0.isArchived && ($0.status == .scheduled || $0.status == .queued || $0.status == .inProgress)
        }.count
        guard activeCount >= 220 else { return nil }

        let timestamp = now()
        if let last = lastCompactionAt, timestamp.timeIntervalSince(last) < compactionCooldown {
            return nil
        }

        guard let report = taskService.compactTaskBacklogIfNeeded(minimumActiveTasks: 180, maxMerges: 100),
              report.mergedTaskCount > 0 else {
            return nil
        }

        lastCompactionAt = timestamp
        saveState()

        let reportPath = writeCompactionReport(report: report, generatedAt: timestamp)
        await notifyScope(report: report, reportPath: reportPath)
        return "Scope compaction pass merged \(report.mergedTaskCount) tasks to reduce scope creep."
    }

    private func notifyScope(report: TaskService.TaskCompactionReport, reportPath: String) async {
        let sampleGroups = report.groups.prefix(12).map { group in
            let project = group.projectName ?? "Unspecified"
            let agent = group.assignedAgent ?? "Unassigned"
            return "- Keeper: \(group.keeperId.uuidString) | merged \(group.mergedIds.count) | project=\(project) | agent=\(agent)"
        }.joined(separator: "\n")

        let message = """
        [scope-compaction-review]
        Task backlog exceeded threshold and was compacted automatically.
        Active queued/ready scanned: \(report.scannedActiveCount)
        Merged tasks: \(report.mergedTaskCount)
        Report: \(reportPath)
        Merge groups (sample):
        \(sampleGroups)

        Action required:
        1) Verify merged groups are logically compatible and necessary.
        2) If any merge is too aggressive, create corrective split task(s) with owners.
        3) Add one governance task that prevents further scope creep.
        """

        _ = try? await gatewayService.sendAgentMessage(
            agentId: "scope",
            message: message,
            sessionKey: nil,
            thinkingEnabled: true
        )
    }

    private func writeCompactionReport(report: TaskService.TaskCompactionReport, generatedAt: Date) -> String {
        let timestamp = ISO8601DateFormatter().string(from: generatedAt).replacingOccurrences(of: ":", with: "-")
        let path = "\(reportsDirectoryPath)/scope_compaction_\(timestamp).md"

        let groups = report.groups.map { group in
            let project = group.projectName ?? "Unspecified"
            let agent = group.assignedAgent ?? "Unassigned"
            let mergedList = group.mergedIds.map { $0.uuidString }.joined(separator: ", ")
            return """
            - Keeper: \(group.keeperId.uuidString)
              Project: \(project)
              Agent: \(agent)
              Key: \(group.normalizedKey)
              Merged: \(mergedList)
            """
        }.joined(separator: "\n")

        let content = """
        # Scope Compaction Report

        Generated: \(generatedAt.shortString)
        Scanned Active Tasks: \(report.scannedActiveCount)
        Total Merged Tasks: \(report.mergedTaskCount)

        ## Merge Groups
        \(groups)
        """

        do {
            try FileManager.default.createDirectory(atPath: reportsDirectoryPath, withIntermediateDirectories: true)
            try content.write(toFile: path, atomically: true, encoding: .utf8)
            return path
        } catch {
            return "Failed to write compaction report: \(error.localizedDescription)"
        }
    }

    private func loadState() {
        guard FileManager.default.fileExists(atPath: stateFilePath) else { return }
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: stateFilePath))
            let decoded = try JSONDecoder().decode(CompactionState.self, from: data)
            lastCompactionAt = decoded.lastCompactionAt
        } catch {
            lastCompactionAt = nil
        }
    }

    private func saveState() {
        do {
            let payload = CompactionState(lastCompactionAt: lastCompactionAt)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(payload)
            let stateDir = URL(fileURLWithPath: stateFilePath).deletingLastPathComponent().path
            try FileManager.default.createDirectory(atPath: stateDir, withIntermediateDirectories: true)
            try data.write(to: URL(fileURLWithPath: stateFilePath), options: .atomic)
        } catch {
            print("[TaskCompactionService] Failed to save state: \(error)")
        }
    }
}
