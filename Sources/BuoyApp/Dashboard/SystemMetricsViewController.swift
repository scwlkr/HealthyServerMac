import AppKit
import Foundation

public final class SystemMetricsViewController: NSViewController, DashboardConsumer {
    private let textView = NSTextView()
    private let timestampLabel = NSTextField(labelWithString: "—")
    private let intervalPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    weak var coordinator: RefreshCoordinator?

    public override func loadView() {
        view = NSView()
        view.wantsLayer = true
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        buildLayout()
    }

    public override func viewDidAppear() {
        super.viewDidAppear()
        if coordinator == nil, let main = parent as? BuoyMainViewController {
            coordinator = main.coordinator
            syncPopup()
        }
    }

    private func syncPopup() {
        guard let coord = coordinator else { return }
        if let idx = RefreshInterval.allCases.firstIndex(of: coord.currentInterval) {
            intervalPopup.selectItem(at: idx)
        }
    }

    private func buildLayout() {
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.drawsBackground = false

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        scroll.documentView = textView
        scroll.translatesAutoresizingMaskIntoConstraints = false

        let refreshLabel = NSTextField(labelWithString: "Refresh rate:")
        refreshLabel.font = NSFont.systemFont(ofSize: 12)
        intervalPopup.addItems(withTitles: RefreshInterval.allCases.map { $0.label })
        intervalPopup.target = self
        intervalPopup.action = #selector(intervalChanged)

        timestampLabel.font = NSFont.systemFont(ofSize: 11)
        timestampLabel.textColor = .secondaryLabelColor

        let controls = NSStackView(views: [refreshLabel, intervalPopup, NSView(), timestampLabel])
        controls.orientation = .horizontal
        controls.alignment = .centerY
        controls.spacing = 8
        controls.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [controls, scroll])
        stack.orientation = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 360)
        ])
    }

    @objc private func intervalChanged() {
        let idx = intervalPopup.indexOfSelectedItem
        guard idx >= 0, idx < RefreshInterval.allCases.count else { return }
        coordinator?.setInterval(RefreshInterval.allCases[idx])
    }

    public func dashboardDidUpdate(_ snapshot: DashboardSnapshot) {
        var lines: [String] = []
        lines.append("═══ CPU ═══")
        lines.append(String(format: "  Overall:   %6.1f %%", snapshot.cpu.overallPercent))
        if let f = snapshot.cpu.frequencyGHz {
            lines.append(String(format: "  Frequency: %6.2f GHz", f))
        } else {
            lines.append("  Frequency: n/a")
        }
        for (i, c) in snapshot.cpu.perCorePercent.enumerated() {
            lines.append(String(format: "  Core %2d:   %6.1f %%", i, c))
        }

        lines.append("")
        lines.append("═══ Memory ═══")
        lines.append(String(format: "  Total:     %7.2f GB", snapshot.memory.totalGB))
        lines.append(String(format: "  Used:      %7.2f GB", snapshot.memory.usedGB))
        lines.append(String(format: "  Available: %7.2f GB", snapshot.memory.availableGB))
        lines.append(String(format: "  Usage:     %6.1f %%", snapshot.memory.usagePercent))

        lines.append("")
        lines.append("═══ Disk (\(snapshot.disk.mountPoint)) ═══")
        lines.append(String(format: "  Total:     %7.2f GB", snapshot.disk.totalGB))
        lines.append(String(format: "  Used:      %7.2f GB", snapshot.disk.usedGB))
        lines.append(String(format: "  Available: %7.2f GB", snapshot.disk.availableGB))
        lines.append(String(format: "  Usage:     %6.1f %%", snapshot.disk.usagePercent))

        lines.append("")
        lines.append("═══ Power / Battery ═══")
        lines.append("  Source:    \(snapshot.power.powerSource)")
        if let p = snapshot.power.batteryPercent {
            lines.append(String(format: "  Charge:    %d %%", p))
        }
        lines.append("  Status:    \(chargingStatus(for: snapshot.power))")
        if let t = snapshot.power.timeRemainingMinutes {
            lines.append("  Time left: \(DashboardFormatters.duration(minutes: t))")
        }
        if let c = snapshot.power.condition {
            lines.append("  Condition: \(c)")
        }
        if let w = snapshot.power.wattageDraw {
            lines.append(String(format: "  Wattage:   %.2f W", w))
        }

        lines.append("")
        lines.append("═══ Thermal ═══")
        if let t = snapshot.thermal.cpuTempCelsius {
            lines.append(String(format: "  CPU temp:     %5.1f °C", t))
        } else {
            lines.append("  CPU temp:     unavailable (needs entitlement)")
        }
        if let b = snapshot.thermal.batteryTempCelsius {
            lines.append(String(format: "  Battery temp: %5.1f °C", b))
        } else {
            lines.append("  Battery temp: unavailable")
        }
        if let lvl = snapshot.thermal.thermalLevel {
            lines.append("  Pressure:     \(lvl)")
        }

        textView.string = lines.joined(separator: "\n")

        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm:ss"
        timestampLabel.stringValue = "Last updated \(fmt.string(from: snapshot.capturedAt))"
    }

    private func chargingStatus(for power: PowerSnapshot) -> String {
        if power.isCharging {
            return "Charging"
        }
        if power.batteryPercent == 100, power.powerSource.localizedCaseInsensitiveContains("AC") {
            return "Charged"
        }
        return "Not charging"
    }
}
