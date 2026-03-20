import AppKit

@MainActor protocol CapabilityMapDelegate: AnyObject {
    func capabilityMapDidRequestBack()
}

final class CapabilityMapViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    weak var delegate: CapabilityMapDelegate?

    private let backButton = NSButton(title: "Back to Dashboard", target: nil, action: nil)
    private let summaryLabel = NSTextField(wrappingLabelWithString: "")
    private let splitView = NSSplitView()
    private let toolsTableView = NSTableView()
    private let itemsTableView = NSTableView()

    private var toolMap: [(tool: String, items: [SkillItem])] = []
    private var selectedToolIndex: Int = -1
    private var allItems: [SkillItem] = []

    override func loadView() {
        view = NSView()

        backButton.target = self
        backButton.action = #selector(backClicked)
        backButton.bezelStyle = .rounded
        backButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backButton)

        summaryLabel.font = .systemFont(ofSize: 13)
        summaryLabel.textColor = .secondaryLabelColor
        summaryLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(summaryLabel)

        // Tools table (left)
        let toolsColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("tool"))
        toolsColumn.title = "Tool"
        toolsTableView.addTableColumn(toolsColumn)
        toolsTableView.headerView = nil
        toolsTableView.dataSource = self
        toolsTableView.delegate = self
        toolsTableView.rowHeight = 28
        toolsTableView.tag = 1

        let toolsScroll = NSScrollView()
        toolsScroll.documentView = toolsTableView
        toolsScroll.hasVerticalScroller = true

        // Items table (right)
        let itemsColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("item"))
        itemsColumn.title = "Item"
        itemsTableView.addTableColumn(itemsColumn)
        itemsTableView.headerView = nil
        itemsTableView.dataSource = self
        itemsTableView.delegate = self
        itemsTableView.rowHeight = 28
        itemsTableView.tag = 2

        let itemsScroll = NSScrollView()
        itemsScroll.documentView = itemsTableView
        itemsScroll.hasVerticalScroller = true

        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.addSubview(toolsScroll)
        splitView.addSubview(itemsScroll)
        splitView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(splitView)

        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),

            summaryLabel.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            summaryLabel.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: 16),
            summaryLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -16),

            splitView.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 12),
            splitView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            splitView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    func updateWithItems(_ items: [SkillItem]) {
        allItems = items

        // Build tool → items map
        var map: [String: [SkillItem]] = [:]
        for item in items {
            guard let allowedTools = item.allowedTools else { continue }
            let tools = parseToolsList(allowedTools)
            for tool in tools {
                map[tool, default: []].append(item)
            }
        }

        toolMap = map.sorted { $0.value.count > $1.value.count }.map { (tool: $0.key, items: $0.value) }

        // Summary stats
        let uniqueTools = toolMap.count
        let mostUsed = toolMap.first?.tool ?? "N/A"
        let widest = items.max(by: {
            parseToolsList($0.allowedTools ?? "").count < parseToolsList($1.allowedTools ?? "").count
        })
        let widestName = widest?.name ?? "N/A"

        summaryLabel.stringValue = "\(uniqueTools) unique tools | Most used: \(mostUsed) | Widest access: \(widestName)"

        selectedToolIndex = -1
        toolsTableView.reloadData()
        itemsTableView.reloadData()
    }

    private func parseToolsList(_ raw: String) -> [String] {
        let stripped = raw.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        return stripped.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "\"'")) }
            .filter { !$0.isEmpty }
    }

    @objc private func backClicked() {
        delegate?.capabilityMapDidRequestBack()
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView.tag == 1 {
            return toolMap.count
        } else {
            guard selectedToolIndex >= 0, selectedToolIndex < toolMap.count else { return 0 }
            return toolMap[selectedToolIndex].items.count
        }
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cellId = NSUserInterfaceItemIdentifier(tableView.tag == 1 ? "ToolCell" : "ItemCell")
        let cell: NSTableCellView
        if let existing = tableView.makeView(withIdentifier: cellId, owner: nil) as? NSTableCellView {
            cell = existing
        } else {
            cell = NSTableCellView()
            cell.identifier = cellId
            let tf = NSTextField(labelWithString: "")
            tf.font = .systemFont(ofSize: 13)
            tf.lineBreakMode = .byTruncatingTail
            tf.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(tf)
            cell.textField = tf
            NSLayoutConstraint.activate([
                tf.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
                tf.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
                tf.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
        }

        if tableView.tag == 1 {
            let entry = toolMap[row]
            cell.textField?.stringValue = "\(entry.tool) (\(entry.items.count))"
        } else if selectedToolIndex >= 0, selectedToolIndex < toolMap.count {
            let item = toolMap[selectedToolIndex].items[row]
            cell.textField?.stringValue = "\(item.name) [\(item.kind.displayName)]"
        }

        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let tableView = notification.object as? NSTableView, tableView.tag == 1 else { return }
        selectedToolIndex = tableView.selectedRow
        itemsTableView.reloadData()
    }
}
