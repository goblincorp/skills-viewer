import AppKit

final class DetailViewController: NSViewController {
    private let scrollView = NSScrollView()
    private let stackView = NSStackView()
    private let emptyLabel = NSTextField(labelWithString: "Select a skill to view details")

    private var currentItem: SkillItem?

    override func loadView() {
        view = NSView()

        // Empty state
        emptyLabel.font = .systemFont(ofSize: 16, weight: .medium)
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyLabel)

        // Scroll view with stack
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 12
        stackView.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)

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
        nameLabel.font = .systemFont(ofSize: 24, weight: .bold)
        stackView.addArrangedSubview(nameLabel)

        // Badges row
        let badgeRow = NSStackView()
        badgeRow.orientation = .horizontal
        badgeRow.spacing = 8
        badgeRow.addArrangedSubview(makeBadge(item.kind.displayName, color: colorForKind(item.kind)))
        badgeRow.addArrangedSubview(makeBadge(item.source == .local ? "Local" : "Plugin", color: .systemGray))
        stackView.addArrangedSubview(badgeRow)

        // Description
        if !item.description.isEmpty {
            addSection("Description", value: item.description)
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

        // File path (clickable)
        let pathHeader = NSTextField(labelWithString: "File Path")
        pathHeader.font = .systemFont(ofSize: 12, weight: .semibold)
        pathHeader.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(pathHeader)

        let pathButton = NSButton(title: item.path, target: self, action: #selector(revealInFinder))
        pathButton.bezelStyle = .inline
        pathButton.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        stackView.addArrangedSubview(pathButton)
    }

    private func addSection(_ title: String, value: String) {
        let header = NSTextField(labelWithString: title)
        header.font = .systemFont(ofSize: 12, weight: .semibold)
        header.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(header)

        let body = NSTextField(wrappingLabelWithString: value)
        body.font = .systemFont(ofSize: 14)
        body.usesSingleLineMode = false
        stackView.addArrangedSubview(body)
    }

    private func makeBadge(_ text: String, color: NSColor) -> NSView {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 11, weight: .medium)
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
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
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
}
