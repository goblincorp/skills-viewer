import AppKit

extension NSToolbarItem.Identifier {
    static let sidebarTrackingSeparator = NSToolbarItem.Identifier("sidebarTrackingSeparator")
    static let filterSegment = NSToolbarItem.Identifier("filterSegment")
    static let searchField = NSToolbarItem.Identifier("searchField")
    static let toggleInspector = NSToolbarItem.Identifier("toggleInspector")
}

final class MainViewController: NSSplitViewController, SkillListDelegate, DetailViewDelegate, DashboardDelegate, CapabilityMapDelegate, NSToolbarDelegate, NSSearchFieldDelegate {
    private let listVC = SkillListViewController()
    private let markdownVC = MarkdownViewController()
    private let detailVC = DetailViewController()
    private let dashboardVC = DashboardViewController()
    private let capabilityMapVC = CapabilityMapViewController()

    private var rightSidebarItem: NSSplitViewItem!
    private var centerItem: NSSplitViewItem!
    private var fileWatcher: FileWatcher?
    private var currentItems: [SkillItem] = []

    // Toolbar controls (retained for forwarding)
    private let toolbarSearchField = NSSearchField()
    private let toolbarSegmentedControl = NSSegmentedControl()

    // The center container holds all center-pane views; we toggle visibility
    private let centerContainer = NSView()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Left sidebar (skill list)
        let listItem = NSSplitViewItem(sidebarWithViewController: listVC)
        listItem.minimumThickness = 280
        listItem.maximumThickness = 400
        listItem.canCollapse = true
        listItem.holdingPriority = NSLayoutConstraint.Priority(252)
        addSplitViewItem(listItem)

        // Center pane — uses a container VC that hosts markdown, dashboard, and capability map
        let centerVC = NSViewController()
        centerVC.view = centerContainer
        centerContainer.translatesAutoresizingMaskIntoConstraints = false

        // Add child views to center container
        for childVC in [markdownVC, dashboardVC, capabilityMapVC] as [NSViewController] {
            childVC.view.translatesAutoresizingMaskIntoConstraints = false
            centerContainer.addSubview(childVC.view)
            NSLayoutConstraint.activate([
                childVC.view.topAnchor.constraint(equalTo: centerContainer.topAnchor),
                childVC.view.leadingAnchor.constraint(equalTo: centerContainer.leadingAnchor),
                childVC.view.trailingAnchor.constraint(equalTo: centerContainer.trailingAnchor),
                childVC.view.bottomAnchor.constraint(equalTo: centerContainer.bottomAnchor),
            ])
        }

        centerItem = NSSplitViewItem(viewController: centerVC)
        centerItem.minimumThickness = 400
        centerItem.canCollapse = false
        centerItem.holdingPriority = NSLayoutConstraint.Priority(250)
        addSplitViewItem(centerItem)

        // Right sidebar — inspector pattern (overlays content like Xcode)
        rightSidebarItem = NSSplitViewItem(inspectorWithViewController: detailVC)
        rightSidebarItem.minimumThickness = 220
        rightSidebarItem.maximumThickness = 320
        rightSidebarItem.canCollapse = true
        rightSidebarItem.holdingPriority = NSLayoutConstraint.Priority(251)
        addSplitViewItem(rightSidebarItem)

        listVC.delegate = self
        detailVC.delegate = self
        dashboardVC.delegate = self
        capabilityMapVC.delegate = self

        // Load items
        currentItems = Scanner.scanAll()
        listVC.setItems(currentItems)

        // Show dashboard initially
        showCenterView(.dashboard)
        dashboardVC.updateWithItems(currentItems)

        // Watch for file changes
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        fileWatcher = FileWatcher(paths: [
            "\(home)/.claude",
            "\(home)/.claude/skills",
            "\(home)/.claude/plugins",
        ]) { [weak self] in
            self?.reloadItems()
        }
        fileWatcher?.start()
    }

    private func reloadItems() {
        currentItems = Scanner.scanAll()
        listVC.setItems(currentItems)
        dashboardVC.updateWithItems(currentItems)
        capabilityMapVC.updateWithItems(currentItems)
    }

    private enum CenterPane {
        case markdown, dashboard, capabilityMap
    }

    private func showCenterView(_ pane: CenterPane) {
        markdownVC.view.isHidden = pane != .markdown
        dashboardVC.view.isHidden = pane != .dashboard
        capabilityMapVC.view.isHidden = pane != .capabilityMap
    }

    // MARK: - SkillListDelegate

    func skillList(_ controller: SkillListViewController, didSelect item: SkillItem?) {
        if let item = item {
            showCenterView(.markdown)
            markdownVC.showItem(item)
        } else {
            showCenterView(.dashboard)
            dashboardVC.updateWithItems(currentItems)
        }
        detailVC.showItem(item)
    }

    // MARK: - DetailViewDelegate

    func detailView(_ controller: DetailViewController, didSelectFile file: AssociatedFile) {
        showCenterView(.markdown)
        markdownVC.showMarkdownFile(file.path)
    }

    // MARK: - DashboardDelegate

    func dashboardDidRequestCapabilityMap() {
        showCenterView(.capabilityMap)
        capabilityMapVC.updateWithItems(currentItems)
    }

    // MARK: - CapabilityMapDelegate

    func capabilityMapDidRequestBack() {
        showCenterView(.dashboard)
        dashboardVC.updateWithItems(currentItems)
    }

    // toggleInspector(_:) is inherited from NSSplitViewController (macOS 14+)
    // and automatically toggles the inspector split view item.

    // MARK: - NSToolbarDelegate

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch itemIdentifier {
        case .sidebarTrackingSeparator:
            return NSTrackingSeparatorToolbarItem(identifier: .sidebarTrackingSeparator, splitView: splitView, dividerIndex: 0)

        case .filterSegment:
            let labels = ["All", "Skill", "Cmd", "Agent", "Plugin", "Hook", "CLAUDE"]
            toolbarSegmentedControl.segmentCount = labels.count
            for (i, label) in labels.enumerated() {
                toolbarSegmentedControl.setLabel(label, forSegment: i)
            }
            toolbarSegmentedControl.selectedSegment = 0
            toolbarSegmentedControl.segmentStyle = .roundRect
            toolbarSegmentedControl.target = self
            toolbarSegmentedControl.action = #selector(toolbarFilterChanged(_:))

            let item = NSToolbarItem(itemIdentifier: .filterSegment)
            item.label = "Filter"
            item.view = toolbarSegmentedControl
            return item

        case .searchField:
            let item = NSSearchToolbarItem(itemIdentifier: .searchField)
            item.searchField.delegate = self
            item.searchField.placeholderString = "Search skills..."
            return item

        case .toggleInspector:
            let item = NSToolbarItem(itemIdentifier: .toggleInspector)
            item.label = "Toggle Inspector"
            item.image = NSImage(systemSymbolName: "sidebar.trailing", accessibilityDescription: "Toggle Inspector")
            item.action = #selector(NSSplitViewController.toggleInspector(_:))
            item.isBordered = true
            return item

        default:
            return nil
        }
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.toggleSidebar, .sidebarTrackingSeparator, .filterSegment, .searchField, .toggleInspector]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    // MARK: - Toolbar Actions

    @objc private func toolbarFilterChanged(_ sender: NSSegmentedControl) {
        forwardFilterToList()
    }

    func controlTextDidChange(_ obj: Notification) {
        forwardFilterToList()
    }

    private func forwardFilterToList() {
        let query: String
        if let searchItem = view.window?.toolbar?.items.first(where: { $0.itemIdentifier == .searchField }) as? NSSearchToolbarItem {
            query = searchItem.searchField.stringValue
        } else {
            query = ""
        }
        let kindIndex = toolbarSegmentedControl.selectedSegment
        listVC.applyExternalFilter(query: query, kindIndex: kindIndex)
    }
}
