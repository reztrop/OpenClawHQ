import Foundation

struct SkillInfo: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let description: String
    let emoji: String
    let source: String
    let homepage: String?
    let agentsWithAccess: [String]
}
