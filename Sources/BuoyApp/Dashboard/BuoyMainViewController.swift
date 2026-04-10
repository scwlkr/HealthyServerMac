import AppKit
import Foundation

/// Root tab controller that hosts the preserved Power panel plus the new dashboard tabs.
public final class BuoyMainViewController: NSTabViewController {
    public let coordinator = RefreshCoordinator()
    private let powerVC: BuoyViewController
    private let overviewVC = OverviewViewController()
    private let systemVC = SystemMetricsViewController()
    private let processesVC = ProcessesViewController()
    private let servicesVC = ServicesViewController()
    private let networkVC = NetworkViewController()

    public init(powerVC: BuoyViewController) {
        self.powerVC = powerVC
        super.init(nibName: nil, bundle: nil)
        self.tabStyle = .toolbar
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    public override func viewDidLoad() {
        super.viewDidLoad()

        addTab(powerVC, label: "Power", symbol: "bolt.fill")
        addTab(overviewVC, label: "Overview", symbol: "gauge")
        addTab(systemVC, label: "System", symbol: "cpu")
        addTab(processesVC, label: "Processes", symbol: "list.bullet.rectangle")
        addTab(servicesVC, label: "Services", symbol: "gearshape.2")
        addTab(networkVC, label: "Network", symbol: "network")

        [overviewVC, systemVC, processesVC, servicesVC, networkVC].forEach {
            coordinator.addConsumer($0)
        }
    }

    public override func viewDidAppear() {
        super.viewDidAppear()
        if let window = view.window {
            coordinator.attach(window: window)
        }
        coordinator.start()
    }

    public override func viewWillDisappear() {
        super.viewWillDisappear()
        coordinator.stop()
    }

    private func addTab(_ vc: NSViewController, label: String, symbol: String) {
        let item = NSTabViewItem(viewController: vc)
        item.label = label
        if #available(macOS 11.0, *) {
            item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        }
        addTabViewItem(item)
    }
}
