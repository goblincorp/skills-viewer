import AppKit

final class MainViewController: NSSplitViewController, SkillListDelegate {
    private let listVC = SkillListViewController()
    private let detailVC = DetailViewController()

    override func viewDidLoad() {
        super.viewDidLoad()

        let listItem = NSSplitViewItem(viewController: listVC)
        listItem.minimumThickness = 280
        listItem.maximumThickness = 400
        listItem.canCollapse = false
        listItem.holdingPriority = .defaultHigh
        addSplitViewItem(listItem)

        let detailItem = NSSplitViewItem(viewController: detailVC)
        detailItem.minimumThickness = 300
        detailItem.canCollapse = false
        detailItem.holdingPriority = .defaultLow
        addSplitViewItem(detailItem)

        listVC.delegate = self

        // Load items
        let items = Scanner.scanAll()
        listVC.setItems(items)
    }

    // MARK: - SkillListDelegate

    func skillList(_ controller: SkillListViewController, didSelect item: SkillItem?) {
        detailVC.showItem(item)
    }
}
