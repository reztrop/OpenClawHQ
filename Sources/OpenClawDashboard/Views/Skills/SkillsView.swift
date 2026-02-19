import SwiftUI

struct SkillsView: View {
    @EnvironmentObject var skillsViewModel: SkillsViewModel
    @State private var searchText = ""

    private var filteredSkills: [SkillInfo] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return skillsViewModel.skills }
        return skillsViewModel.skills.filter { skill in
            skill.name.localizedCaseInsensitiveContains(query) ||
            skill.description.localizedCaseInsensitiveContains(query) ||
            skill.agentsWithAccess.contains(where: { $0.localizedCaseInsensitiveContains(query) })
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ConnectionBanner()
                header
                skillsCard
            }
            .padding(24)
        }
        .background(Theme.darkBackground)
        .task {
            await skillsViewModel.refreshSkills()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Skills")
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.white)
            Text("Enabled skills available to your agents.")
                .foregroundColor(Theme.textMuted)
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var skillsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Theme.textMuted)
                    TextField("Search skills", text: $searchText)
                        .textFieldStyle(.plain)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Theme.darkAccent)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Theme.darkBorder, lineWidth: 1)
                )
                .cornerRadius(8)

                Button {
                    Task { await skillsViewModel.refreshSkills() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(Theme.jarvisBlue)
            }

            HStack {
                Text("\(filteredSkills.count) shown")
                    .font(.caption)
                    .foregroundColor(Theme.textMuted)
                Spacer()
                if skillsViewModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if let error = skillsViewModel.errorMessage {
                Text(error)
                    .foregroundColor(Theme.statusOffline)
                    .font(.caption)
            }

            if filteredSkills.isEmpty {
                Text("No enabled skills found.")
                    .foregroundColor(Theme.textMuted)
                    .frame(maxWidth: .infinity, minHeight: 140)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(filteredSkills) { skill in
                        skillRow(skill)
                    }
                }
            }
        }
        .padding(18)
        .background(Theme.darkSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.darkBorder, lineWidth: 1)
        )
        .cornerRadius(12)
    }

    private func skillRow(_ skill: SkillInfo) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(skill.emoji)
                .font(.title2)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(skill.name)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("enabled")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(Theme.statusOnline)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.statusOnline.opacity(0.15))
                        .cornerRadius(8)
                    Text(skill.source)
                        .font(.caption2)
                        .foregroundColor(Theme.textMuted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.darkAccent.opacity(0.8))
                        .cornerRadius(8)
                    Spacer()
                }

                Text(skill.description)
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if !skill.agentsWithAccess.isEmpty {
                    HStack(spacing: 6) {
                        Text("Agents:")
                            .font(.caption)
                            .foregroundColor(Theme.textMuted)
                        ForEach(skill.agentsWithAccess, id: \.self) { agent in
                            Text(agent.capitalized)
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Theme.agentColor(for: agent).opacity(0.25))
                                .cornerRadius(7)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Theme.darkAccent.opacity(0.45))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Theme.darkBorder.opacity(0.8), lineWidth: 1)
        )
        .cornerRadius(10)
    }
}
