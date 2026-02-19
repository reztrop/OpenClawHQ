import Foundation

@MainActor
class ProjectsViewModel: ObservableObject {
    @Published var projects: [ProjectRecord] = []
    @Published var selectedProjectId: String?
    @Published var statusMessage: String?
    @Published var isApproving = false

    private let filePath: String
    private let taskService: TaskService
    private let gatewayService: GatewayService

    init(taskService: TaskService, gatewayService: GatewayService, filePath: String = Constants.projectsFilePath) {
        self.taskService = taskService
        self.gatewayService = gatewayService
        self.filePath = filePath
        load()
    }

    var selectedProject: ProjectRecord? {
        guard let id = selectedProjectId else { return nil }
        return projects.first(where: { $0.id == id })
    }

    func load() {
        guard FileManager.default.fileExists(atPath: filePath) else {
            let id = createProject(title: "New Project")
            selectedProjectId = id
            save()
            return
        }

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            if let state = try? decoder.decode(ProjectsStateFile.self, from: data) {
                projects = state.projects.sorted(by: { $0.updatedAt > $1.updatedAt })
                selectedProjectId = state.selectedProjectId ?? projects.first?.id
                return
            }

            if let legacy = try? decoder.decode(ProductBlueprint.self, from: data) {
                let fallbackTitle = legacy.projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "Recovered Project"
                    : legacy.projectName
                let recovered = ProjectRecord(
                    id: UUID().uuidString,
                    title: fallbackTitle,
                    conversationId: nil,
                    createdAt: Date(),
                    updatedAt: Date(),
                    approvedStages: [],
                    blueprint: legacy
                )
                projects = [recovered]
                selectedProjectId = recovered.id
                save()
                statusMessage = "Recovered existing project plan into the new Projects sidebar."
                return
            }

            throw NSError(domain: "OpenClawHQ", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unsupported projects file format"])
        } catch {
            projects = [ProjectRecord.makeNew(title: "New Project")]
            selectedProjectId = projects.first?.id
            statusMessage = "Failed to load project plans. Started with a fresh project."
            save()
        }
    }

    func save() {
        do {
            projects.sort { $0.updatedAt > $1.updatedAt }
            let state = ProjectsStateFile(selectedProjectId: selectedProjectId, projects: projects)
            let parent = URL(fileURLWithPath: filePath).deletingLastPathComponent()
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(state)
            try data.write(to: URL(fileURLWithPath: filePath), options: .atomic)
        } catch {
            statusMessage = "Failed to save project plan."
        }
    }

    @discardableResult
    func createProject(title: String, conversationId: String? = nil, overview: String? = nil) -> String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle = trimmedTitle.isEmpty ? "New Project" : trimmedTitle
        let record = ProjectRecord.makeNew(title: finalTitle, conversationId: conversationId, overview: overview)
        projects.insert(record, at: 0)
        selectedProjectId = record.id
        save()
        return record.id
    }

    func deleteProject(_ id: String) {
        projects.removeAll { $0.id == id }
        if selectedProjectId == id {
            selectedProjectId = projects.first?.id
        }
        if projects.isEmpty {
            selectedProjectId = createProject(title: "New Project")
        }
        save()
    }

    func selectProject(_ id: String) {
        guard projects.contains(where: { $0.id == id }) else { return }
        selectedProjectId = id
        save()
    }

    func registerProjectKickoff(conversationId: String, userPrompt: String) {
        if let existingIdx = projects.firstIndex(where: { $0.conversationId == conversationId }) {
            selectedProjectId = projects[existingIdx].id
            projects[existingIdx].updatedAt = Date()
            save()
            statusMessage = "Linked to existing project from Jarvis chat."
            return
        }

        let title = titleFromKickoff(userPrompt)
        let overview = cleanedKickoffPrompt(userPrompt)
        _ = createProject(title: title, conversationId: conversationId, overview: overview)
        statusMessage = "Created new project from [project] chat kickoff."
    }

    func updateProjectTitle(_ title: String) {
        updateSelected { project in
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            let finalTitle = trimmed.isEmpty ? "New Project" : trimmed
            project.title = finalTitle
            project.blueprint.projectName = finalTitle
        }
    }

    func setStage(_ stage: ProductStage) {
        updateSelected { project in
            project.blueprint.activeStage = stage
        }
    }

    func updateOverview(_ text: String) {
        updateSelected { $0.blueprint.overview = text }
    }

    func updateProblems(_ text: String) {
        updateSelected { $0.blueprint.problemsText = text }
    }

    func updateFeatures(_ text: String) {
        updateSelected { $0.blueprint.featuresText = text }
    }

    func updateDataModel(_ text: String) {
        updateSelected { $0.blueprint.dataModelText = text }
    }

    func updateDesign(_ text: String) {
        updateSelected { $0.blueprint.designText = text }
    }

    func updateSectionsDraft(_ text: String) {
        updateSelected { $0.blueprint.sectionsDraftText = text }
    }

    func updateExportNotes(_ text: String) {
        updateSelected { $0.blueprint.exportNotes = text }
    }

    func setSectionCompletion(_ id: String, completed: Bool) {
        updateSelected { project in
            guard let idx = project.blueprint.sections.firstIndex(where: { $0.id == id }) else { return }
            project.blueprint.sections[idx].completed = completed
        }
    }

    func approveCurrentStage() async {
        guard var project = selectedProject else { return }
        guard !isApproving else { return }

        let currentStage = project.blueprint.activeStage
        guard let nextStage = currentStage.next else {
            statusMessage = "Project is already at final stage."
            return
        }

        isApproving = true
        statusMessage = "Dispatching Jarvis to draft \(nextStage.rawValue)..."

        let prompt = approvalPrompt(for: project, approvedStage: currentStage, targetStage: nextStage)

        do {
            let response = try await gatewayService.sendAgentMessage(
                agentId: "jarvis",
                message: prompt,
                sessionKey: project.conversationId,
                thinkingEnabled: true
            )

            let draft = normalizedDraft(response.text)
            if let sessionKey = response.sessionKey {
                project.conversationId = sessionKey
            }

            if !project.approvedStages.contains(currentStage) {
                project.approvedStages.append(currentStage)
            }

            switch nextStage {
            case .dataModel:
                project.blueprint.dataModelText = draft
            case .design:
                project.blueprint.designText = draft
            case .sections:
                project.blueprint.sectionsDraftText = draft
            case .export:
                project.blueprint.exportNotes = draft
            case .product:
                break
            }

            project.blueprint.activeStage = nextStage
            project.updatedAt = Date()
            project.blueprint.lastUpdated = Date()
            saveUpdated(project)

            statusMessage = "Approved \(currentStage.rawValue). Team drafted \(nextStage.rawValue)."
        } catch {
            statusMessage = "Approval failed: \(error.localizedDescription)"
        }

        isApproving = false
    }

    func exportMarkdown() -> String {
        guard let project = selectedProject else { return "# No Project Selected" }
        let blueprint = project.blueprint
        let completedCount = blueprint.sections.filter { $0.completed }.count
        let sectionLines = blueprint.sections.map {
            "- [\($0.completed ? "x" : " ")] \($0.title) (\($0.ownerAgent)) - \($0.summary)"
        }.joined(separator: "\n")

        return """
        # \(project.title)

        ## Overview
        \(blueprint.overview)

        ## Problems & Solutions
        \(blueprint.problemsText)

        ## Key Features
        \(blueprint.featuresText)

        ## Data Model
        \(blueprint.dataModelText)

        ## Design
        \(blueprint.designText)

        ## Sections Draft
        \(blueprint.sectionsDraftText)

        ## Sections (\(completedCount)/\(blueprint.sections.count) complete)
        \(sectionLines)

        ## Export Notes
        \(blueprint.exportNotes)
        """
    }

    private func approvalPrompt(for project: ProjectRecord, approvedStage: ProductStage, targetStage: ProductStage) -> String {
        let b = project.blueprint

        return """
        [project-approval]
        Project: \(project.title)
        Approved Stage: \(approvedStage.rawValue)
        Target Stage To Draft: \(targetStage.rawValue)

        You are Jarvis coordinating Scope, Atlas, Matrix, and Prism.
        The approved content below is final. Use it to generate a strong first-pass draft for ONLY the target stage.

        Approved Product Definition:
        Overview:
        \(b.overview)

        Problems & Solutions:
        \(b.problemsText)

        Key Features:
        \(b.featuresText)

        Existing Data Model:
        \(b.dataModelText)

        Existing Design:
        \(b.designText)

        Existing Sections Draft:
        \(b.sectionsDraftText)

        Response rules:
        - Return only the draft content for \(targetStage.rawValue).
        - Be concrete and execution-ready.
        - Include ownership hints (Jarvis/Scope/Atlas/Matrix/Prism) where useful.
        - Do not include wrapper commentary or markdown code fences.
        """
    }

    private func normalizedDraft(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "No draft returned. Ask Jarvis to retry this stage."
        }
        return trimmed
    }

    private func cleanedKickoffPrompt(_ raw: String) -> String {
        raw.replacingOccurrences(of: "[project]", with: "", options: [.caseInsensitive])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func titleFromKickoff(_ raw: String) -> String {
        let cleaned = cleanedKickoffPrompt(raw)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        if cleaned.isEmpty { return "New Project" }
        if cleaned.count <= 54 { return cleaned }
        return String(cleaned.prefix(54)).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }

    private func saveUpdated(_ project: ProjectRecord) {
        guard let idx = projects.firstIndex(where: { $0.id == project.id }) else { return }
        projects[idx] = project
        save()
    }

    private func updateSelected(_ mutate: (inout ProjectRecord) -> Void) {
        guard let id = selectedProjectId,
              let idx = projects.firstIndex(where: { $0.id == id }) else { return }

        var copy = projects[idx]
        mutate(&copy)
        copy.updatedAt = Date()
        copy.blueprint.lastUpdated = Date()
        projects[idx] = copy
        save()
    }
}
