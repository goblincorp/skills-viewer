import AppKit

@MainActor protocol DetailViewDelegate: AnyObject {
    func detailView(_ controller: DetailViewController, didSelectFile file: AssociatedFile)
}

final class DetailViewController: NSViewController {
    private let scrollView = NSScrollView()
    private let stackView = NSStackView()
    private let emptyLabel = NSTextField(labelWithString: "Select a skill to view details")

    private var currentItem: SkillItem?
    weak var delegate: DetailViewDelegate?

    override func loadView() {
        view = NSView()

        // Empty state
        emptyLabel.font = .systemFont(ofSize: 14, weight: .medium)
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyLabel)

        // Scroll view with stack
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 10
        stackView.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)

        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = stackView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.isHidden = true
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stackView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
        ])
    }

    func showItem(_ item: SkillItem?) {
        currentItem = item

        // Clear existing views
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        guard let item = item else {
            emptyLabel.isHidden = false
            scrollView.isHidden = true
            return
        }

        emptyLabel.isHidden = true
        scrollView.isHidden = false

        // Name
        let nameLabel = NSTextField(labelWithString: item.name)
        nameLabel.font = .systemFont(ofSize: 20, weight: .bold)
        nameLabel.lineBreakMode = .byWordWrapping
        nameLabel.maximumNumberOfLines = 0
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        stackView.addArrangedSubview(nameLabel)

        // Badges row
        let badgeRow = NSStackView()
        badgeRow.orientation = .horizontal
        badgeRow.spacing = 6
        badgeRow.addArrangedSubview(makeBadge(item.kind.displayName, color: colorForKind(item.kind)))
        badgeRow.addArrangedSubview(makeBadge(item.source == .local ? "Local" : "Plugin", color: .systemGray))
        stackView.addArrangedSubview(badgeRow)

        // Description
        if !item.description.isEmpty {
            addFormattedDescription(item.description)
        }

        if let pluginName = item.pluginName {
            addSection("Plugin", value: pluginName)
        }
        if let version = item.version {
            addSection("Version", value: version)
        }
        if let author = item.author {
            addSection("Author", value: author)
        }
        if let hint = item.argumentHint {
            addSection("Argument Hint", value: hint)
        }
        if let tools = item.allowedTools {
            addSection("Allowed Tools", value: tools)
        }

        // Dates
        if item.createdDate != nil || item.modifiedDate != nil {
            addSeparator()
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .none
            if let modified = item.modifiedDate {
                addSection("Modified", value: dateFormatter.string(from: modified))
            }
            if let created = item.createdDate {
                addSection("Created", value: dateFormatter.string(from: created))
            }
        }

        // Associated markdown files
        let mdFiles = item.associatedFiles.filter { $0.isMarkdown }
        if !mdFiles.isEmpty {
            addSeparator()
            let header = NSTextField(labelWithString: "Files")
            header.font = .systemFont(ofSize: 12, weight: .semibold)
            header.textColor = .secondaryLabelColor
            stackView.addArrangedSubview(header)

            for file in mdFiles {
                let button = NSButton(title: file.name, target: self, action: #selector(fileClicked(_:)))
                button.bezelStyle = .inline
                button.font = .systemFont(ofSize: 12)
                button.tag = item.associatedFiles.firstIndex(where: { $0.path == file.path }) ?? 0
                stackView.addArrangedSubview(button)
            }
        }

        // Other (non-markdown) files
        let otherFiles = item.associatedFiles.filter { !$0.isMarkdown }
        if !otherFiles.isEmpty {
            addSeparator()
            let header = NSTextField(labelWithString: "Other Files")
            header.font = .systemFont(ofSize: 12, weight: .semibold)
            header.textColor = .secondaryLabelColor
            stackView.addArrangedSubview(header)

            for file in otherFiles {
                let button = NSButton(title: file.name, target: self, action: #selector(revealFile(_:)))
                button.bezelStyle = .inline
                button.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
                button.tag = item.associatedFiles.firstIndex(where: { $0.path == file.path }) ?? 0
                stackView.addArrangedSubview(button)
            }
        }

        // Primary file path
        addSeparator()
        let pathHeader = NSTextField(labelWithString: "File Path")
        pathHeader.font = .systemFont(ofSize: 12, weight: .semibold)
        pathHeader.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(pathHeader)

        let pathButton = NSButton(title: item.path, target: self, action: #selector(revealInFinder))
        pathButton.bezelStyle = .inline
        pathButton.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        pathButton.lineBreakMode = .byTruncatingMiddle
        stackView.addArrangedSubview(pathButton)
    }

    private func addSection(_ title: String, value: String) {
        let header = NSTextField(labelWithString: title)
        header.font = .systemFont(ofSize: 12, weight: .semibold)
        header.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(header)

        let body = NSTextField(wrappingLabelWithString: value)
        body.font = .systemFont(ofSize: 13)
        body.usesSingleLineMode = false
        body.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        stackView.addArrangedSubview(body)
    }

    private func addFormattedDescription(_ raw: String) {
        let header = NSTextField(labelWithString: "Description")
        header.font = .systemFont(ofSize: 12, weight: .semibold)
        header.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(header)

        // Replace literal \n with real newlines
        var text = raw.replacingOccurrences(of: "\\n", with: "\n")

        // Strip XML-like tags and extract structure
        let tagPattern = #"<\/?(example|commentary|context|command-name|example_agent_descriptions)[^>]*>"#
        let hasStructuredContent = text.range(of: tagPattern, options: .regularExpression) != nil

        if hasStructuredContent {
            // Split into main description and examples
            let parts = text.components(separatedBy: "<example")
            let mainDesc = parts[0]
                .replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: "Examples:", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !mainDesc.isEmpty {
                let descField = NSTextField(wrappingLabelWithString: mainDesc)
                descField.font = .systemFont(ofSize: 13)
                descField.usesSingleLineMode = false
                descField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
                stackView.addArrangedSubview(descField)
            }

            // Show examples
            if parts.count > 1 {
                let examplesHeader = NSTextField(labelWithString: "Examples")
                examplesHeader.font = .systemFont(ofSize: 12, weight: .semibold)
                examplesHeader.textColor = .secondaryLabelColor
                stackView.addArrangedSubview(examplesHeader)

                for i in 1..<parts.count {
                    let exampleText = parts[i]
                        .replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !exampleText.isEmpty else { continue }

                    // Extract context, user, and assistant lines
                    let attributed = formatExample(exampleText, index: i)
                    let exampleField = NSTextField(labelWithString: "")
                    exampleField.attributedStringValue = attributed
                    exampleField.usesSingleLineMode = false
                    exampleField.maximumNumberOfLines = 0
                    exampleField.lineBreakMode = .byWordWrapping
                    exampleField.preferredMaxLayoutWidth = 0
                    exampleField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

                    // Wrap in a subtle box
                    let box = NSBox()
                    box.boxType = .custom
                    box.cornerRadius = 6
                    box.borderWidth = 0
                    box.fillColor = .quaternaryLabelColor
                    box.contentViewMargins = NSSize(width: 10, height: 8)
                    box.contentView = exampleField
                    box.translatesAutoresizingMaskIntoConstraints = false
                    stackView.addArrangedSubview(box)
                    box.widthAnchor.constraint(equalTo: stackView.widthAnchor, constant: -32).isActive = true
                }
            }
        } else {
            // No structured content — just clean up and display
            text = text.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let body = NSTextField(wrappingLabelWithString: text)
            body.font = .systemFont(ofSize: 13)
            body.usesSingleLineMode = false
            body.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            stackView.addArrangedSubview(body)
        }
    }

    private func formatExample(_ text: String, index: Int) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let normalFont = NSFont.systemFont(ofSize: 12)
        let boldFont = NSFont.systemFont(ofSize: 12, weight: .semibold)
        let normalColor = NSColor.labelColor
        let secondaryColor = NSColor.secondaryLabelColor

        let lines = text.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            if !result.string.isEmpty {
                result.append(NSAttributedString(string: "\n"))
            }

            if trimmed.lowercased().hasPrefix("context:") {
                let value = String(trimmed.dropFirst(8)).trimmingCharacters(in: .whitespaces)
                result.append(NSAttributedString(string: "Context: ", attributes: [.font: boldFont, .foregroundColor: secondaryColor]))
                result.append(NSAttributedString(string: value, attributes: [.font: normalFont, .foregroundColor: secondaryColor]))
            } else if trimmed.lowercased().hasPrefix("user:") {
                let value = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                result.append(NSAttributedString(string: "User: ", attributes: [.font: boldFont, .foregroundColor: normalColor]))
                result.append(NSAttributedString(string: value, attributes: [.font: normalFont, .foregroundColor: normalColor]))
            } else if trimmed.lowercased().hasPrefix("assistant:") {
                let value = String(trimmed.dropFirst(10)).trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                result.append(NSAttributedString(string: "Assistant: ", attributes: [.font: boldFont, .foregroundColor: normalColor]))
                result.append(NSAttributedString(string: value, attributes: [.font: normalFont, .foregroundColor: normalColor]))
            } else {
                result.append(NSAttributedString(string: trimmed, attributes: [.font: normalFont, .foregroundColor: secondaryColor]))
            }
        }

        return result
    }

    private func addSeparator() {
        let sep = NSBox()
        sep.boxType = .separator
        stackView.addArrangedSubview(sep)
        sep.widthAnchor.constraint(equalTo: stackView.widthAnchor, constant: -32).isActive = true
    }

    private func makeBadge(_ text: String, color: NSColor) -> NSView {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 10, weight: .medium)
        label.textColor = .white
        label.backgroundColor = color
        label.drawsBackground = true
        label.isBezeled = false
        label.alignment = .center

        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = color.cgColor
        container.layer?.cornerRadius = 4
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 2),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -2),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -6),
        ])
        return container
    }

    private func colorForKind(_ kind: ItemKind) -> NSColor {
        switch kind {
        case .skill: return .systemBlue
        case .command: return .systemGreen
        case .agent: return .systemPurple
        case .plugin: return .systemOrange
        }
    }

    @objc private func revealInFinder() {
        guard let item = currentItem else { return }
        NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
    }

    @objc private func fileClicked(_ sender: NSButton) {
        guard let item = currentItem, sender.tag < item.associatedFiles.count else { return }
        let file = item.associatedFiles[sender.tag]
        delegate?.detailView(self, didSelectFile: file)
    }

    @objc private func revealFile(_ sender: NSButton) {
        guard let item = currentItem, sender.tag < item.associatedFiles.count else { return }
        let file = item.associatedFiles[sender.tag]
        NSWorkspace.shared.selectFile(file.path, inFileViewerRootedAtPath: "")
    }
}
