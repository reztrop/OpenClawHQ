import Foundation

@MainActor
class SettingsService: ObservableObject {
    @Published var settings: AppSettings

    init() {
        settings = Self.load()
        migrateLegacyModelIds()
    }

    func update(_ transform: (inout AppSettings) -> Void) {
        transform(&settings)
        save()
    }

    func resetToDefaults() {
        settings = .default
        save()
    }

    func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(settings)
            try data.write(to: URL(fileURLWithPath: AppSettings.filePath))
        } catch {
            print("[Settings] Failed to save: \(error)")
        }
    }

    private static func load() -> AppSettings {
        let path = AppSettings.filePath
        guard FileManager.default.fileExists(atPath: path),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return .default
        }
        return settings
    }

    /// Migrates older bare model IDs (e.g. "gpt-5.3-codex") to provider-qualified
    /// IDs used by current gateway builds.
    private func migrateLegacyModelIds() {
        var changed = false

        for idx in settings.localAgents.indices {
            let before = settings.localAgents[idx].modelId
            settings.localAgents[idx].modelId = ModelNormalizer.normalize(before)
            if before != settings.localAgents[idx].modelId {
                changed = true
            }
        }

        changed = migrateOpenClawConfigModels() || changed

        if changed {
            save()
        }
    }

    /// Updates ~/.openclaw/openclaw.json agent model entries in place when they
    /// are stored without provider prefixes.
    private func migrateOpenClawConfigModels() -> Bool {
        let path = Constants.openclawConfigPath
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              var json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              var agents = json["agents"] as? [String: Any] else {
            return false
        }

        var changed = false

        if var defaults = agents["defaults"] as? [String: Any],
           var model = defaults["model"] as? [String: Any],
           let primary = model["primary"] as? String {
            let normalized = ModelNormalizer.normalize(primary) ?? primary
            if normalized != primary {
                model["primary"] = normalized
                defaults["model"] = model
                agents["defaults"] = defaults
                changed = true
            }
        }

        if var list = agents["list"] as? [[String: Any]] {
            for idx in list.indices {
                if let model = list[idx]["model"] as? String {
                    let normalized = ModelNormalizer.normalize(model) ?? model
                    if normalized != model {
                        list[idx]["model"] = normalized
                        changed = true
                    }
                }
            }
            if changed {
                agents["list"] = list
            }
        }

        guard changed else { return false }

        json["agents"] = agents
        guard let out = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]) else {
            return false
        }
        do {
            try out.write(to: URL(fileURLWithPath: path))
            return true
        } catch {
            print("[Settings] Failed to migrate openclaw.json model IDs: \(error)")
            return false
        }
    }
}
