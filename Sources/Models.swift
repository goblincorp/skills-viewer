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
    case hook
    case claudeMd

    var displayName: String {
        switch self {
        case .claudeMd: return "CLAUDE.md"
        default: return rawValue.capitalized
        }
    }

    var sfSymbol: String {
        switch self {
        case .skill: return "star.fill"
        case .command: return "terminal.fill"
        case .agent: return "cpu.fill"
        case .plugin: return "puzzlepiece.fill"
        case .hook: return "bolt.fill"
        case .claudeMd: return "doc.text.fill"
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
    let model: String?
    let color: String?
    let tools: String?
    let keywords: String?
    let homepage: String?
    let repository: String?
    let license: String?
    let directoryPath: String
    let associatedFiles: [AssociatedFile]
    let createdDate: Date?
    let modifiedDate: Date?
    let hookType: String?
    let matcher: String?
    let hookCommand: String?
    let body: String
}
