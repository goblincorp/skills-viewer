import AppKit

final class MainViewController: NSSplitViewController, SkillListDelegate, DetailViewDelegate, DashboardDelegate, CapabilityMapDelegate {
    private let listVC = SkillListViewController()
    private let markdownVC = MarkdownViewController()
    private let detailVC = DetailViewController()
    private let dashboardVC = DashboardViewController()
    private let capabilityMapVC = CapabilityMapViewController()

    private var rightSidebarItem: NSSplitViewItem!
    private var centerItem: NSSplitViewItem!
    private var fileWatcher: FileWatcher?
    private var currentItems: [SkillItem] = []

    // The center container holds all center-pane views; we toggle visibility
    private let centerContainer = NSView()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Left sidebar (skill list)
        let listItem = NSSplitViewItem(sidebarWithViewController: listVC)
        listItem.minimumThickness = 280
        listItem.maximumThickness = 400
        listItem.canCollapse = false
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

        // Right sidebar (detail/metadata)
        rightSidebarItem = NSSplitViewItem(viewController: detailVC)
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

    // MARK: - Toggle Right Sidebar

    @objc func toggleRightSidebar(_ sender: Any?) {
        rightSidebarItem.animator().isCollapsed.toggle()
    }
}
