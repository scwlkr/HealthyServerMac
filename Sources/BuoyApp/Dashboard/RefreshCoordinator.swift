import AppKit
import Foundation

/// Refresh cadence options exposed by the System Metrics tab.
public enum RefreshInterval: TimeInterval, CaseIterable {
    case twoSeconds = 2
    case fiveSeconds = 5
    case tenSeconds = 10
    case thirtySeconds = 30
    case oneMinute = 60

    public var label: String {
        switch self {
        case .twoSeconds: return "2 sec"
        case .fiveSeconds: return "5 sec"
        case .tenSeconds: return "10 sec"
        case .thirtySeconds: return "30 sec"
        case .oneMinute: return "1 min"
        }
    }
}

public protocol DashboardConsumer: AnyObject {
    func dashboardDidUpdate(_ snapshot: DashboardSnapshot)
}

/// Owns a single background collection queue and a timer. Broadcasts snapshots
/// to all registered consumers on the main thread. Pauses while the window is
/// hidden/miniaturized.
public final class RefreshCoordinator {
    private let collector = MetricsCollector()
    private let queue = DispatchQueue(label: "buoy.metrics.collector", qos: .utility)
    private var timer: DispatchSourceTimer?
    private weak var observedWindow: NSWindow?
    private var consumers: [WeakBox] = []
    private var inFlight = false
    public private(set) var currentInterval: RefreshInterval = .twoSeconds
    public private(set) var latestSnapshot: DashboardSnapshot?

    public init() {}

    public func attach(window: NSWindow) {
        observedWindow = window
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(windowStateChanged), name: NSWindow.didMiniaturizeNotification, object: window)
        nc.addObserver(self, selector: #selector(windowStateChanged), name: NSWindow.didDeminiaturizeNotification, object: window)
    }

    public func addConsumer(_ consumer: DashboardConsumer) {
        consumers.append(WeakBox(value: consumer))
        if let snap = latestSnapshot {
            DispatchQueue.main.async { consumer.dashboardDidUpdate(snap) }
        }
    }

    public func start() {
        stop()
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + 0.1, repeating: currentInterval.rawValue)
        t.setEventHandler { [weak self] in self?.tick() }
        timer = t
        t.resume()
    }

    public func stop() {
        timer?.cancel()
        timer = nil
    }

    public func setInterval(_ interval: RefreshInterval) {
        currentInterval = interval
        if timer != nil {
            start()
        }
    }

    public func refreshNow() {
        queue.async { [weak self] in self?.tick() }
    }

    @objc private func windowStateChanged(_ note: Notification) {
        if let win = observedWindow, win.isMiniaturized {
            stop()
        } else {
            start()
        }
    }

    private func tick() {
        if inFlight { return }
        inFlight = true
        let snapshot = collector.collect()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.latestSnapshot = snapshot
            self.consumers.removeAll { $0.value == nil }
            for box in self.consumers {
                (box.value as? DashboardConsumer)?.dashboardDidUpdate(snapshot)
            }
            self.inFlight = false
        }
    }

    private final class WeakBox {
        weak var value: AnyObject?
        init(value: AnyObject) { self.value = value }
    }
}
