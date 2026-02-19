import Foundation

enum ModelNormalizer {
    static let defaultProvider = "openai-codex"

    /// Normalizes model IDs to provider-qualified form expected by gateway.
    /// Examples:
    /// - "gpt-5.3-codex" -> "openai-codex/gpt-5.3-codex"
    /// - "openai-codex/gpt-5.3-codex" -> unchanged
    static func normalize(_ modelId: String?) -> String? {
        guard let raw = modelId?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }
        guard !raw.contains("/") else { return raw }

        let lower = raw.lowercased()
        if lower.hasPrefix("claude") {
            return "anthropic/\(raw)"
        }
        return "\(defaultProvider)/\(raw)"
    }

    static func normalizeInPlace(_ modelId: inout String?) {
        modelId = normalize(modelId)
    }
}
