import SwiftUI
import AppKit

struct ProjectsView: View {
    @EnvironmentObject var projectsVM: ProjectsViewModel

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 300)
            Divider().background(Theme.darkBorder)
            detail
        }
        .background(Theme.darkBackground)
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Projects")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                Spacer()
                Button {
                    _ = projectsVM.createProject(title: "New Project")
                } label: {
                    Label("New", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(12)

            Divider().background(Theme.darkBorder)

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(projectsVM.projects) { project in
                        Button {
                            projectsVM.selectProject(project.id)
                        } label: {
                            projectRow(project)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Delete Project", role: .destructive) {
                                projectsVM.deleteProject(project.id)
                            }
                        }
                    }
                }
                .padding(10)
            }
        }
        .background(Theme.darkSurface)
    }

    private func projectRow(_ project: ProjectRecord) -> some View {
        let isSelected = projectsVM.selectedProjectId == project.id
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(project.title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)
                Spacer()
                if let stage = project.blueprint.activeStage.next {
                    Text(stage.rawValue)
                        .font(.caption2)
                        .foregroundColor(Theme.textMuted)
                } else {
                    Text("Done")
                        .font(.caption2)
                        .foregroundColor(Theme.statusOnline)
                }
            }
            Text(project.blueprint.overview)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
                .lineLimit(2)
            Text(project.updatedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption2)
                .foregroundColor(Theme.textMuted)
        }
        .padding(10)
        .background(isSelected ? Theme.darkAccent : Theme.darkBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Theme.jarvisBlue : Theme.darkBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private var detail: some View {
        if let project = projectsVM.selectedProject {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    detailHeader(project)
                    stageBar(project)
                    stageContent(project)
                    if let status = projectsVM.statusMessage {
                        Text(status)
                            .font(.caption)
                            .foregroundColor(Theme.textMuted)
                    }
                }
                .padding(24)
                .frame(maxWidth: 980, alignment: .leading)
            }
        } else {
            VStack(spacing: 10) {
                Text("No Project Selected")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                Text("Create a project from here or start one in Jarvis chat using [project].")
                    .foregroundColor(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func detailHeader(_ project: ProjectRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledTextField(
                title: "Project Name",
                text: Binding(
                    get: { project.title },
                    set: { projectsVM.updateProjectTitle($0) }
                ),
                onCommit: { }
            )
            Text("Use [project] in Jarvis chat to initialize new project threads. Approve each stage to trigger team drafting of the next one.")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
        }
    }

    private func stageBar(_ project: ProjectRecord) -> some View {
        HStack(spacing: 10) {
            ForEach(ProductStage.allCases) { stage in
                Button {
                    projectsVM.setStage(stage)
                } label: {
                    HStack(spacing: 8) {
                        if project.approvedStages.contains(stage) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Theme.statusOnline)
                        } else {
                            Image(systemName: stage.icon)
                        }
                        Text(stage.rawValue)
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .foregroundColor(project.blueprint.activeStage == stage ? .black : Theme.textSecondary)
                    .background(project.blueprint.activeStage == stage ? Theme.jarvisBlue : Theme.darkSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Theme.darkBorder, lineWidth: project.blueprint.activeStage == stage ? 0 : 1)
                    )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private func stageContent(_ project: ProjectRecord) -> some View {
        switch project.blueprint.activeStage {
        case .product:
            productStage(project)
        case .dataModel:
            singleTextStage(
                title: "Data Model",
                subtitle: "Team draft generated after Product approval. Edit as needed, then approve.",
                value: Binding(
                    get: { project.blueprint.dataModelText },
                    set: { projectsVM.updateDataModel($0) }
                ),
                saveAction: { projectsVM.save() },
                approveAction: { Task { await projectsVM.approveCurrentStage() } },
                approveLabel: project.blueprint.activeStage.approveLabel,
                isApproving: projectsVM.isApproving
            )
        case .design:
            singleTextStage(
                title: "Design",
                subtitle: "System and UI draft generated after Data Model approval.",
                value: Binding(
                    get: { project.blueprint.designText },
                    set: { projectsVM.updateDesign($0) }
                ),
                saveAction: { projectsVM.save() },
                approveAction: { Task { await projectsVM.approveCurrentStage() } },
                approveLabel: project.blueprint.activeStage.approveLabel,
                isApproving: projectsVM.isApproving
            )
        case .sections:
            sectionsStage(project)
        case .export:
            exportStage(project)
        }
    }

    private func productStage(_ project: ProjectRecord) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            stageCardTitle("Product", "Define scope and outcomes before team drafting starts.")
            LabeledTextEditor(
                title: "Project Overview",
                text: Binding(get: { project.blueprint.overview }, set: { projectsVM.updateOverview($0) }),
                minHeight: 110,
                onCommit: { }
            )
            HStack(spacing: 12) {
                LabeledTextEditor(
                    title: "Problems & Solutions",
                    text: Binding(get: { project.blueprint.problemsText }, set: { projectsVM.updateProblems($0) }),
                    minHeight: 170,
                    onCommit: { }
                )
                LabeledTextEditor(
                    title: "Key Features",
                    text: Binding(get: { project.blueprint.featuresText }, set: { projectsVM.updateFeatures($0) }),
                    minHeight: 170,
                    onCommit: { }
                )
            }
            HStack(spacing: 10) {
                Button("Save") { projectsVM.save() }
                    .buttonStyle(.bordered)
                Button(project.blueprint.activeStage.approveLabel) {
                    Task { await projectsVM.approveCurrentStage() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(projectsVM.isApproving)
            }
        }
        .padding(16)
        .background(Theme.darkSurface)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.darkBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func sectionsStage(_ project: ProjectRecord) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            stageCardTitle("Sections", "Team-generated section draft plus completion tracking.")
            LabeledTextEditor(
                title: "Sections Draft",
                text: Binding(get: { project.blueprint.sectionsDraftText }, set: { projectsVM.updateSectionsDraft($0) }),
                minHeight: 180,
                onCommit: { }
            )

            ForEach(project.blueprint.sections) { section in
                HStack(alignment: .top, spacing: 12) {
                    Toggle("", isOn: Binding(
                        get: { section.completed },
                        set: { projectsVM.setSectionCompletion(section.id, completed: $0) }
                    ))
                    .toggleStyle(.checkbox)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(section.title)
                                .font(.headline)
                                .foregroundColor(.white)
                            Spacer()
                            Text(section.ownerAgent)
                                .font(.caption)
                                .foregroundColor(Theme.textMuted)
                        }
                        Text(section.summary)
                            .foregroundColor(Theme.textSecondary)
                            .font(.subheadline)
                    }
                }
                .padding(12)
                .background(Theme.darkBackground)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.darkBorder, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            HStack(spacing: 10) {
                Button("Save") { projectsVM.save() }
                    .buttonStyle(.bordered)
                Button(project.blueprint.activeStage.approveLabel) {
                    Task { await projectsVM.approveCurrentStage() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(projectsVM.isApproving)
            }
        }
        .padding(16)
        .background(Theme.darkSurface)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.darkBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func exportStage(_ project: ProjectRecord) -> some View {
        let markdown = projectsVM.exportMarkdown()
        return VStack(alignment: .leading, spacing: 14) {
            stageCardTitle("Export", "Final package and rollout notes.")
            LabeledTextEditor(
                title: "Export Notes",
                text: Binding(get: { project.blueprint.exportNotes }, set: { projectsVM.updateExportNotes($0) }),
                minHeight: 140,
                onCommit: { }
            )
            Text(markdown)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(Theme.textSecondary)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.darkBackground)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.darkBorder, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            HStack(spacing: 10) {
                Button("Save") { projectsVM.save() }
                    .buttonStyle(.bordered)
                Button("Copy Markdown") {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString(markdown, forType: .string)
                    projectsVM.statusMessage = "Export copied to clipboard."
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .background(Theme.darkSurface)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.darkBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func singleTextStage(
        title: String,
        subtitle: String,
        value: Binding<String>,
        saveAction: @escaping () -> Void,
        approveAction: @escaping () -> Void,
        approveLabel: String,
        isApproving: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            stageCardTitle(title, subtitle)
            LabeledTextEditor(title: title, text: value, minHeight: 280, onCommit: { })
            HStack(spacing: 10) {
                Button("Save") { saveAction() }
                    .buttonStyle(.bordered)
                Button(approveLabel) { approveAction() }
                    .buttonStyle(.borderedProminent)
                    .disabled(isApproving)
            }
        }
        .padding(16)
        .background(Theme.darkSurface)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.darkBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func stageCardTitle(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title2.bold())
                .foregroundColor(.white)
            Text(subtitle)
                .foregroundColor(Theme.textSecondary)
        }
    }
}

private struct LabeledTextField: View {
    let title: String
    @Binding var text: String
    var onCommit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .foregroundColor(Theme.textMuted)
                .font(.caption)
            TextField("", text: $text, onCommit: onCommit)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Theme.darkBackground)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.darkBorder, lineWidth: 1))
                .foregroundColor(.white)
        }
    }
}

private struct LabeledTextEditor: View {
    let title: String
    @Binding var text: String
    let minHeight: CGFloat
    var onCommit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .foregroundColor(Theme.textMuted)
                .font(.caption)
            TextEditor(text: $text)
                .font(.body)
                .foregroundColor(.white)
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(minHeight: minHeight)
                .background(Theme.darkBackground)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.darkBorder, lineWidth: 1))
                .onChange(of: text) { _, _ in onCommit() }
        }
    }
}
