import AppKit

@MainActor
protocol SkillListDelegate: AnyObject {
    func skillList(_ controller: SkillListViewController, didSelect item: SkillItem?)
}

final class SidebarNode {
    let title: String
    let item: SkillItem?
    var children: [SidebarNode]

    init(title: String, item: SkillItem?, children: [SidebarNode] = []) {
        self.title = title
        self.item = item
        self.children = children
    }

    var isGroup: Bool { item?.kind == .plugin && !children.isEmpty }
}

final class SkillListViewController: NSViewController, NSOutlineViewDataSource, NSOutlineViewDelegate, NSSearchFieldDelegate {
    weak var delegate: SkillListDelegate?

    private let searchField = NSSearchField()
    private let segmentedControl = NSSegmentedControl()
    private let scrollView = NSScrollView()
    private let outlineView = NSOutlineView()

    private var allItems: [SkillItem] = []
    private(set) var filteredItems: [SkillItem] = []
    private var rootNodes: [SidebarNode] = []
    private var isGrouped = true

    private let filterOptions: [(String, ItemKind?)] = [
        ("All", nil),
        ("Skill", .skill),
        ("Cmd", .command),
        ("Agent", .agent),
        ("Plugin", .plugin),
        ("Hook", .hook),
        ("CLAUDE", .claudeMd),
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

        // Outline view
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("main"))
        column.title = "Skills"
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column
        outlineView.headerView = nil
        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.rowHeight = 52
        outlineView.style = .inset
        outlineView.indentationPerLevel = 16

        scrollView.documentView = outlineView
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
                let matchesBody = item.body.lowercased().contains(query)
                if !matchesName && !matchesDesc && !matchesBody { return false }
            }
            return true
        }

        // Use grouped tree when "All" filter with empty search, flat list otherwise
        isGrouped = selectedKind == nil && query.isEmpty
        buildNodes()
        outlineView.reloadData()

        if isGrouped {
            for node in rootNodes where node.isGroup {
                outlineView.expandItem(node)
            }
        }

        delegate?.skillList(self, didSelect: nil)
    }

    private func buildNodes() {
        if !isGrouped {
            // Flat list — each item is a root node
            rootNodes = filteredItems.map { SidebarNode(title: $0.name, item: $0) }
            return
        }

        // Grouped: plugins are parents, their children are nested beneath
        var pluginNodes: [String: SidebarNode] = [:]
        var nonPluginNodes: [SidebarNode] = []

        // First pass: create plugin group nodes
        for item in filteredItems where item.kind == .plugin {
            let node = SidebarNode(title: item.name, item: item)
            pluginNodes[item.name] = node
        }

        // Second pass: assign children or add as root
        for item in filteredItems {
            if item.kind == .plugin { continue }
            if let pluginName = item.pluginName, let parent = pluginNodes[pluginName] {
                parent.children.append(SidebarNode(title: item.name, item: item))
            } else {
                nonPluginNodes.append(SidebarNode(title: item.name, item: item))
            }
        }

        // Build root: non-plugin items first, then plugin groups (sorted)
        let sortedPlugins = pluginNodes.values.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        rootNodes = nonPluginNodes + sortedPlugins
    }

    // MARK: - NSOutlineViewDataSource

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if let node = item as? SidebarNode {
            return node.children.count
        }
        return rootNodes.count
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let node = item as? SidebarNode {
            return node.children[index]
        }
        return rootNodes[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if let node = item as? SidebarNode {
            return !node.children.isEmpty
        }
        return false
    }

    // MARK: - NSOutlineViewDelegate

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let node = item as? SidebarNode, let skillItem = node.item else { return nil }

        let cellId = NSUserInterfaceItemIdentifier("SkillCell")
        let cell: NSTableCellView
        if let existing = outlineView.makeView(withIdentifier: cellId, owner: nil) as? NSTableCellView {
            cell = existing
        } else {
            cell = makeCell(identifier: cellId)
        }

        if let imageView = cell.imageView {
            imageView.image = NSImage(systemSymbolName: skillItem.kind.sfSymbol, accessibilityDescription: skillItem.kind.displayName)
            imageView.contentTintColor = skillItem.kind.color
        }
        if let textField = cell.textField {
            textField.stringValue = skillItem.name
        }
        if let descLabel = cell.viewWithTag(100) as? NSTextField {
            descLabel.stringValue = skillItem.description
        }
        if let badgeLabel = cell.viewWithTag(101) as? NSTextField {
            badgeLabel.stringValue = skillItem.kind.displayName
        }

        return cell
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        let row = outlineView.selectedRow
        guard row >= 0, let node = outlineView.item(atRow: row) as? SidebarNode else {
            delegate?.skillList(self, didSelect: nil)
            return
        }
        delegate?.skillList(self, didSelect: node.item)
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
}
