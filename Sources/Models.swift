import Foundation

enum SkillSource: String {
    case local
    case plugin
}

enum ItemKind: String, CaseIterable {
    case skill
    case command
    case agent
    case plugin

    var displayName: String {
        rawValue.capitalized
    }

    var sfSymbol: String {
        switch self {
        case .skill: return "star.fill"
        case .command: return "terminal.fill"
        case .agent: return "cpu.fill"
        case .plugin: return "puzzlepiece.fill"
        }
    }
}

struct AssociatedFile {
    let name: String
    let path: String
    let isMarkdown: Bool
}

struct SkillItem {
    let name: String
    let description: String
    let version: String?
    let author: String?
    let source: SkillSource
    let kind: ItemKind
    let pluginName: String?
    let path: String
    let argumentHint: String?
    let allowedTools: String?
    let directoryPath: String
    let associatedFiles: [AssociatedFile]
    let createdDate: Date?
    let modifiedDate: Date?
}
