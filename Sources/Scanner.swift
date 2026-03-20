import Foundation

struct Scanner {
    static func scanAll() -> [SkillItem] {
        var items: [SkillItem] = []
        items.append(contentsOf: scanLocalSkills())
        items.append(contentsOf: scanPlugins())
        return items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: - Local Skills

    static func scanLocalSkills() -> [SkillItem] {
        let skillsDir = NSString(string: "~/.claude/skills").expandingTildeInPath
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: skillsDir) else { return [] }

        var items: [SkillItem] = []
        for entry in entries {
            let skillPath = (skillsDir as NSString).appendingPathComponent(entry)
            let mdPath = (skillPath as NSString).appendingPathComponent("SKILL.md")
            guard fm.fileExists(atPath: mdPath),
                  let content = try? String(contentsOfFile: mdPath, encoding: .utf8) else { continue }

            let frontmatter = parseFrontmatter(content)
            let name = frontmatter["name"] ?? entry
            let description = frontmatter["description"] ?? ""
            let associated = discoverAssociatedFiles(in: skillPath, excluding: mdPath)
            let dates = fileDates(at: mdPath)
            items.append(SkillItem(
                name: name,
                description: description,
                version: frontmatter["version"],
                author: frontmatter["author"],
                source: .local,
                kind: .skill,
                pluginName: nil,
                path: mdPath,
                argumentHint: frontmatter["argument-hint"],
                allowedTools: frontmatter["allowed-tools"],
                model: frontmatter["model"],
                color: frontmatter["color"],
                tools: frontmatter["tools"],
                keywords: frontmatter["keywords"],
                homepage: frontmatter["homepage"],
                repository: frontmatter["repository"],
                license: frontmatter["license"],
                directoryPath: skillPath,
                associatedFiles: associated,
                createdDate: dates.created,
                modifiedDate: dates.modified,
                hookType: nil,
                matcher: nil,
                hookCommand: nil
            ))
        }
        return items
    }

    // MARK: - Plugins

    static func scanPlugins() -> [SkillItem] {
        let pluginsDir = NSString(string: "~/.claude/plugins/marketplaces/claude-plugins-official/plugins").expandingTildeInPath
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: pluginsDir) else { return [] }

        var items: [SkillItem] = []
        for entry in entries {
            let pluginPath = (pluginsDir as NSString).appendingPathComponent(entry)
            let jsonPath = (pluginPath as NSString).appendingPathComponent(".claude-plugin/plugin.json")
            guard fm.fileExists(atPath: jsonPath),
                  let data = try? Data(contentsOf: URL(fileURLWithPath: jsonPath)) else { continue }

            let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
            let pluginName = json["name"] as? String ?? entry
            let pluginDesc = json["description"] as? String ?? ""
            let authorDict = json["author"] as? [String: String]
            let authorName = authorDict?["name"]

            // Add the plugin itself
            let pluginAssociated = discoverAssociatedFiles(in: pluginPath, excluding: jsonPath)
            let pluginDates = fileDates(at: jsonPath)
            items.append(SkillItem(
                name: pluginName,
                description: pluginDesc,
                version: json["version"] as? String,
                author: authorName,
                source: .plugin,
                kind: .plugin,
                pluginName: nil,
                path: jsonPath,
                argumentHint: nil,
                allowedTools: nil,
                model: nil,
                color: nil,
                tools: nil,
                keywords: nil,
                homepage: nil,
                repository: nil,
                license: nil,
                directoryPath: pluginPath,
                associatedFiles: pluginAssociated,
                createdDate: pluginDates.created,
                modifiedDate: pluginDates.modified,
                hookType: nil,
                matcher: nil,
                hookCommand: nil
            ))

            // Scan sub-items: skills/, commands/, agents/
            let subDirs: [(String, ItemKind)] = [
                ("skills", .skill), ("commands", .command), ("agents", .agent)
            ]
            for (subDir, kind) in subDirs {
                let subPath = (pluginPath as NSString).appendingPathComponent(subDir)
                guard let subEntries = try? fm.contentsOfDirectory(atPath: subPath) else { continue }
                for file in subEntries where file.hasSuffix(".md") {
                    let filePath = (subPath as NSString).appendingPathComponent(file)
                    guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else { continue }
                    let frontmatter = parseFrontmatter(content)
                    let itemName = frontmatter["name"] ?? String(file.dropLast(3))
                    let fileDir = (filePath as NSString).deletingLastPathComponent
                    let associated = discoverAssociatedFiles(in: fileDir, excluding: filePath)
                    let itemDates = fileDates(at: filePath)
                    items.append(SkillItem(
                        name: itemName,
                        description: frontmatter["description"] ?? "",
                        version: nil,
                        author: authorName,
                        source: .plugin,
                        kind: kind,
                        pluginName: pluginName,
                        path: filePath,
                        argumentHint: frontmatter["argument-hint"],
                        allowedTools: frontmatter["allowed-tools"],
                        model: frontmatter["model"],
                        color: frontmatter["color"],
                        tools: frontmatter["tools"],
                        keywords: frontmatter["keywords"],
                        homepage: frontmatter["homepage"],
                        repository: frontmatter["repository"],
                        license: frontmatter["license"],
                        directoryPath: fileDir,
                        associatedFiles: associated,
                        createdDate: itemDates.created,
                        modifiedDate: itemDates.modified,
                        hookType: nil,
                        matcher: nil,
                        hookCommand: nil
                    ))
                }
            }

            // Scan hooks/hooks.json
            let hooksJsonPath = (pluginPath as NSString).appendingPathComponent("hooks/hooks.json")
            if fm.fileExists(atPath: hooksJsonPath),
               let hooksData = try? Data(contentsOf: URL(fileURLWithPath: hooksJsonPath)),
               let hooksJson = (try? JSONSerialization.jsonObject(with: hooksData)) as? [String: Any] {
                let hooksDesc = hooksJson["description"] as? String ?? ""
                let hooksDates = fileDates(at: hooksJsonPath)
                if let hooksDict = hooksJson["hooks"] as? [String: Any] {
                    for (eventType, value) in hooksDict {
                        guard let entries = value as? [[String: Any]] else { continue }
                        for hookEntry in entries {
                            let entryMatcher = hookEntry["matcher"] as? String
                            let hookCommands = hookEntry["hooks"] as? [[String: Any]] ?? []
                            for hookCmd in hookCommands {
                                let command = hookCmd["command"] as? String ?? ""
                                items.append(SkillItem(
                                    name: eventType,
                                    description: hooksDesc,
                                    version: nil,
                                    author: authorName,
                                    source: .plugin,
                                    kind: .hook,
                                    pluginName: pluginName,
                                    path: hooksJsonPath,
                                    argumentHint: nil,
                                    allowedTools: nil,
                                    model: nil,
                                    color: nil,
                                    tools: nil,
                                    keywords: nil,
                                    homepage: nil,
                                    repository: nil,
                                    license: nil,
                                    directoryPath: (hooksJsonPath as NSString).deletingLastPathComponent,
                                    associatedFiles: [],
                                    createdDate: hooksDates.created,
                                    modifiedDate: hooksDates.modified,
                                    hookType: eventType,
                                    matcher: entryMatcher,
                                    hookCommand: command
                                ))
                            }
                        }
                    }
                }
            }
        }
        return items
    }

    // MARK: - Frontmatter

    static func parseFrontmatter(_ content: String) -> [String: String] {
        let lines = content.components(separatedBy: "\n")
        guard lines.first == "---" else { return [:] }

        var result: [String: String] = [:]
        for line in lines.dropFirst() {
            if line == "---" { break }
            if let colonIndex = line.firstIndex(of: ":") {
                let key = String(line[line.startIndex..<colonIndex]).trimmingCharacters(in: .whitespaces)
                let value = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                result[key] = value
            }
        }
        return result
    }

    /// Splits file content into frontmatter dict and body text (everything after the closing ---)
    static func parseSkillFile(_ content: String) -> (frontmatter: [String: String], body: String) {
        let lines = content.components(separatedBy: "\n")
        guard lines.first == "---" else { return ([:], content) }

        var frontmatter: [String: String] = [:]
        var endIndex = 1
        for i in 1..<lines.count {
            if lines[i] == "---" {
                endIndex = i + 1
                break
            }
            if let colonIndex = lines[i].firstIndex(of: ":") {
                let key = String(lines[i][lines[i].startIndex..<colonIndex]).trimmingCharacters(in: .whitespaces)
                let value = String(lines[i][lines[i].index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                frontmatter[key] = value
            }
        }

        let body = lines.dropFirst(endIndex).joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return (frontmatter, body)
    }

    // MARK: - File Dates

    static func fileDates(at path: String) -> (created: Date?, modified: Date?) {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path) else {
            return (nil, nil)
        }
        return (attrs[.creationDate] as? Date, attrs[.modificationDate] as? Date)
    }

    // MARK: - Associated Files

    static func discoverAssociatedFiles(in directory: String, excluding primaryFile: String) -> [AssociatedFile] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: directory) else { return [] }

        var files: [AssociatedFile] = []
        for entry in entries.sorted() {
            let fullPath = (directory as NSString).appendingPathComponent(entry)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: fullPath, isDirectory: &isDir), !isDir.boolValue else { continue }
            guard fullPath != primaryFile else { continue }
            // Skip hidden files
            guard !entry.hasPrefix(".") else { continue }

            let isMarkdown = entry.hasSuffix(".md")
            files.append(AssociatedFile(name: entry, path: fullPath, isMarkdown: isMarkdown))
        }
        return files
    }
}
