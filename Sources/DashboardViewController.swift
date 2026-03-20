import AppKit

@MainActor protocol DashboardDelegate: AnyObject {
    func dashboardDidRequestCapabilityMap()
}

final class DashboardViewController: NSViewController {
    weak var delegate: DashboardDelegate?

    private let scrollView = NSScrollView()
    private let stackView = NSStackView()

    override func loadView() {
        view = NSView()

        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 16
        stackView.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        scrollView.documentView = stackView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stackView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
        ])
    }

    func updateWithItems(_ items: [SkillItem]) {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // Title
        let title = NSTextField(labelWithString: "Dashboard")
        title.font = .systemFont(ofSize: 24, weight: .bold)
        stackView.addArrangedSubview(title)

        // Counts by kind
        let kindHeader = NSTextField(labelWithString: "By Kind")
        kindHeader.font = .systemFont(ofSize: 14, weight: .semibold)
        kindHeader.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(kindHeader)

        let kindRow = NSStackView()
        kindRow.orientation = .horizontal
        kindRow.spacing = 12
        kindRow.distribution = .fillEqually

        for kind in ItemKind.allCases {
            let count = items.filter { $0.kind == kind }.count
            let card = makeStatCard(symbol: kind.sfSymbol, count: count, label: kind.displayName, color: kind.color)
            kindRow.addArrangedSubview(card)
        }
        stackView.addArrangedSubview(kindRow)
        kindRow.widthAnchor.constraint(equalTo: stackView.widthAnchor, constant: -48).isActive = true

        // Counts by source
        let sourceHeader = NSTextField(labelWithString: "By Source")
        sourceHeader.font = .systemFont(ofSize: 14, weight: .semibold)
        sourceHeader.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(sourceHeader)

        let sourceRow = NSStackView()
        sourceRow.orientation = .horizontal
        sourceRow.spacing = 12
        sourceRow.distribution = .fillEqually

        let localCount = items.filter { $0.source == .local }.count
        let pluginCount = items.filter { $0.source == .plugin }.count
        sourceRow.addArrangedSubview(makeStatCard(symbol: "house.fill", count: localCount, label: "Local", color: .systemBlue))
        sourceRow.addArrangedSubview(makeStatCard(symbol: "puzzlepiece.fill", count: pluginCount, label: "Plugin", color: .systemOrange))

        // MCP server count
        let mcpCount = items.reduce(0) { $0 + $1.mcpServers.count }
        sourceRow.addArrangedSubview(makeStatCard(symbol: "server.rack", count: mcpCount, label: "MCP Servers", color: .systemIndigo))

        stackView.addArrangedSubview(sourceRow)
        sourceRow.widthAnchor.constraint(equalTo: stackView.widthAnchor, constant: -48).isActive = true

        // Counts by author
        let authors = Dictionary(grouping: items.compactMap { item -> (String, SkillItem)? in
            guard let author = item.author else { return nil }
            return (author, item)
        }, by: { $0.0 })

        if !authors.isEmpty {
            let authorHeader = NSTextField(labelWithString: "By Author")
            authorHeader.font = .systemFont(ofSize: 14, weight: .semibold)
            authorHeader.textColor = .secondaryLabelColor
            stackView.addArrangedSubview(authorHeader)

            let sortedAuthors = authors.sorted { $0.value.count > $1.value.count }
            for (author, entries) in sortedAuthors {
                let row = NSStackView()
                row.orientation = .horizontal
                row.spacing = 8

                let nameLabel = NSTextField(labelWithString: author)
                nameLabel.font = .systemFont(ofSize: 13)
                row.addArrangedSubview(nameLabel)

                let countLabel = NSTextField(labelWithString: "\(entries.count)")
                countLabel.font = .systemFont(ofSize: 13, weight: .semibold)
                countLabel.textColor = .secondaryLabelColor
                countLabel.alignment = .right
                row.addArrangedSubview(countLabel)

                stackView.addArrangedSubview(row)
            }
        }

        // View Capability Map button
        let capButton = NSButton(title: "View Capability Map", target: self, action: #selector(capabilityMapClicked))
        capButton.bezelStyle = .rounded
        capButton.controlSize = .large
        stackView.addArrangedSubview(capButton)
    }

    @objc private func capabilityMapClicked() {
        delegate?.dashboardDidRequestCapabilityMap()
    }

    private func makeStatCard(symbol: String, count: Int, label: String, color: NSColor) -> NSView {
        let card = NSBox()
        card.boxType = .custom
        card.fillColor = .quaternaryLabelColor
        card.cornerRadius = 8
        card.borderWidth = 0

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false

        let iconView = NSImageView()
        iconView.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        iconView.contentTintColor = color
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 24).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 24).isActive = true
        stack.addArrangedSubview(iconView)

        let countLabel = NSTextField(labelWithString: "\(count)")
        countLabel.font = .systemFont(ofSize: 20, weight: .bold)
        countLabel.alignment = .center
        stack.addArrangedSubview(countLabel)

        let nameLabel = NSTextField(labelWithString: label)
        nameLabel.font = .systemFont(ofSize: 11)
        nameLabel.textColor = .secondaryLabelColor
        nameLabel.alignment = .center
        stack.addArrangedSubview(nameLabel)

        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -8),
        ])

        return card
    }
}
