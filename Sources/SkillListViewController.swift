import AppKit

@MainActor
protocol SkillListDelegate: AnyObject {
    func skillList(_ controller: SkillListViewController, didSelect item: SkillItem?)
}

final class SkillListViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    weak var delegate: SkillListDelegate?

    private let searchField = NSSearchField()
    private let segmentedControl = NSSegmentedControl()
    private let scrollView = NSScrollView()
    private let tableView = NSTableView()

    private var allItems: [SkillItem] = []
    private(set) var filteredItems: [SkillItem] = []

    private let filterOptions: [(String, ItemKind?)] = [
        ("All", nil),
        ("Skill", .skill),
        ("Cmd", .command),
        ("Agent", .agent),
        ("Plugin", .plugin),
        ("Hook", .hook),
    ]

    override func loadView() {
        view = NSView()

        // Search field
        searchField.placeholderString = "Search skills..."
        searchField.delegate = self
        searchField.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchField)

        // Segmented control
        let labels = filterOptions.map(\.0)
        segmentedControl.segmentCount = labels.count
        for (i, label) in labels.enumerated() {
            segmentedControl.setLabel(label, forSegment: i)
        }
        segmentedControl.selectedSegment = 0
        segmentedControl.segmentDistribution = .fillEqually
        segmentedControl.target = self
        segmentedControl.action = #selector(filterChanged)
        segmentedControl.segmentStyle = .roundRect
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(segmentedControl)

        // Table view
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("main"))
        column.title = "Skills"
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 52
        tableView.style = .inset

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            searchField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            searchField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),

            segmentedControl.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 8),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),

            scrollView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    func setItems(_ items: [SkillItem]) {
        allItems = items
        applyFilter()
    }

    // MARK: - Filtering

    @objc private func filterChanged() {
        applyFilter()
    }

    func controlTextDidChange(_ obj: Notification) {
        applyFilter()
    }

    private func applyFilter() {
        let query = searchField.stringValue.lowercased()
        let selectedKind = filterOptions[segmentedControl.selectedSegment].1

        filteredItems = allItems.filter { item in
            if let kind = selectedKind, item.kind != kind { return false }
            if !query.isEmpty {
                let matchesName = item.name.lowercased().contains(query)
                let matchesDesc = item.description.lowercased().contains(query)
                if !matchesName && !matchesDesc { return false }
            }
            return true
        }

        tableView.reloadData()
        delegate?.skillList(self, didSelect: nil)
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        filteredItems.count
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = filteredItems[row]

        let cellId = NSUserInterfaceItemIdentifier("SkillCell")
        let cell: NSTableCellView
        if let existing = tableView.makeView(withIdentifier: cellId, owner: nil) as? NSTableCellView {
            cell = existing
        } else {
            cell = makeCell(identifier: cellId)
        }

        // Update content
        if let imageView = cell.imageView {
            imageView.image = NSImage(systemSymbolName: item.kind.sfSymbol, accessibilityDescription: item.kind.displayName)
            imageView.contentTintColor = colorForKind(item.kind)
        }
        if let textField = cell.textField {
            textField.stringValue = item.name
        }
        // Description label (tag 100)
        if let descLabel = cell.viewWithTag(100) as? NSTextField {
            descLabel.stringValue = item.description
        }
        // Badge label (tag 101)
        if let badgeLabel = cell.viewWithTag(101) as? NSTextField {
            badgeLabel.stringValue = item.kind.displayName
        }

        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        let item = row >= 0 ? filteredItems[row] : nil
        delegate?.skillList(self, didSelect: item)
    }

    // MARK: - Cell Factory

    private func makeCell(identifier: NSUserInterfaceItemIdentifier) -> NSTableCellView {
        let cell = NSTableCellView()
        cell.identifier = identifier

        let imageView = NSImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(imageView)
        cell.imageView = imageView

        let nameLabel = NSTextField(labelWithString: "")
        nameLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(nameLabel)
        cell.textField = nameLabel

        let descLabel = NSTextField(labelWithString: "")
        descLabel.font = .systemFont(ofSize: 11)
        descLabel.textColor = .secondaryLabelColor
        descLabel.lineBreakMode = .byTruncatingTail
        descLabel.tag = 100
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(descLabel)

        let badge = NSTextField(labelWithString: "")
        badge.font = .systemFont(ofSize: 10, weight: .medium)
        badge.textColor = .secondaryLabelColor
        badge.tag = 101
        badge.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(badge)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
            imageView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 24),
            imageView.heightAnchor.constraint(equalToConstant: 24),

            nameLabel.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 8),
            nameLabel.topAnchor.constraint(equalTo: cell.topAnchor, constant: 6),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: badge.leadingAnchor, constant: -4),

            badge.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
            badge.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),

            descLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            descLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            descLabel.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
        ])

        return cell
    }

    private func colorForKind(_ kind: ItemKind) -> NSColor {
        switch kind {
        case .skill: return .systemBlue
        case .command: return .systemGreen
        case .agent: return .systemPurple
        case .plugin: return .systemOrange
        case .hook: return .systemRed
        }
    }
}
