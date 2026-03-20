import AppKit

final class MainViewController: NSSplitViewController, SkillListDelegate, DetailViewDelegate {
    private let listVC = SkillListViewController()
    private let markdownVC = MarkdownViewController()
    private let detailVC = DetailViewController()

    private var rightSidebarItem: NSSplitViewItem!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Left sidebar (skill list)
        let listItem = NSSplitViewItem(sidebarWithViewController: listVC)
        listItem.minimumThickness = 280
        listItem.maximumThickness = 400
        listItem.canCollapse = false
        listItem.holdingPriority = NSLayoutConstraint.Priority(252)
        addSplitViewItem(listItem)

        // Center (markdown viewer)
        let markdownItem = NSSplitViewItem(viewController: markdownVC)
        markdownItem.minimumThickness = 400
        markdownItem.canCollapse = false
        markdownItem.holdingPriority = NSLayoutConstraint.Priority(250)
        addSplitViewItem(markdownItem)

        // Right sidebar (detail/metadata)
        rightSidebarItem = NSSplitViewItem(viewController: detailVC)
        rightSidebarItem.minimumThickness = 220
        rightSidebarItem.maximumThickness = 320
        rightSidebarItem.canCollapse = true
        rightSidebarItem.holdingPriority = NSLayoutConstraint.Priority(251)
        addSplitViewItem(rightSidebarItem)

        listVC.delegate = self
        detailVC.delegate = self

        // Load items
        let items = Scanner.scanAll()
        listVC.setItems(items)
    }

    // MARK: - SkillListDelegate

    func skillList(_ controller: SkillListViewController, didSelect item: SkillItem?) {
        markdownVC.showItem(item)
        detailVC.showItem(item)
    }

    // MARK: - DetailViewDelegate

    func detailView(_ controller: DetailViewController, didSelectFile file: AssociatedFile) {
        markdownVC.showMarkdownFile(file.path)
    }

    // MARK: - Toggle Right Sidebar

    @objc func toggleRightSidebar(_ sender: Any?) {
        rightSidebarItem.animator().isCollapsed.toggle()
    }
}
