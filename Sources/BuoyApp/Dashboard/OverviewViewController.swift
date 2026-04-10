import AppKit
import Foundation

public final class OverviewViewController: NSViewController, DashboardConsumer {
    private let cpuGauge = GaugeView(title: "CPU")
    private let memGauge = GaugeView(title: "Memory")
    private let diskGauge = GaugeView(title: "Disk")
    private let batteryGauge = GaugeView(title: "Battery")
    private let topCPULabel = NSTextField(labelWithString: "Top CPU")
    private let topMemLabel = NSTextField(labelWithString: "Top Memory")
    private let topCPUText = NSTextField(wrappingLabelWithString: "")
    private let topMemText = NSTextField(wrappingLabelWithString: "")
    private let timestampLabel = NSTextField(labelWithString: "—")

    public override func loadView() {
        view = NSView()
        view.wantsLayer = true
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        buildLayout()
    }

    private func buildLayout() {
        let gauges = NSStackView(views: [cpuGauge, memGauge, diskGauge, batteryGauge])
        gauges.orientation = .horizontal
        gauges.distribution = .fillEqually
        gauges.spacing = 14
        gauges.translatesAutoresizingMaskIntoConstraints = false

        [topCPULabel, topMemLabel].forEach {
            $0.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        }
        [topCPUText, topMemText].forEach {
            $0.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
            $0.maximumNumberOfLines = 0
        }

        let cpuBox = makeBox(title: topCPULabel, content: topCPUText)
        let memBox = makeBox(title: topMemLabel, content: topMemText)
        let lists = NSStackView(views: [cpuBox, memBox])
        lists.orientation = .horizontal
        lists.distribution = .fillEqually
        lists.spacing = 14

        timestampLabel.font = NSFont.systemFont(ofSize: 11)
        timestampLabel.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [gauges, lists, timestampLabel])
        stack.orientation = .vertical
        stack.spacing = 16
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            gauges.heightAnchor.constraint(equalToConstant: 120),
            gauges.widthAnchor.constraint(equalTo: stack.widthAnchor),
            lists.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    private func makeBox(title: NSTextField, content: NSTextField) -> NSView {
        let box = NSBox()
        box.boxType = .custom
        box.cornerRadius = 10
        box.borderWidth = 1
        box.fillColor = .controlBackgroundColor
        box.borderColor = .separatorColor
        let s = NSStackView(views: [title, content])
        s.orientation = .vertical
        s.alignment = .leading
        s.spacing = 6
        s.translatesAutoresizingMaskIntoConstraints = false
        box.contentView?.addSubview(s)
        NSLayoutConstraint.activate([
            s.leadingAnchor.constraint(equalTo: box.contentView!.leadingAnchor, constant: 12),
            s.trailingAnchor.constraint(equalTo: box.contentView!.trailingAnchor, constant: -12),
            s.topAnchor.constraint(equalTo: box.contentView!.topAnchor, constant: 10),
            s.bottomAnchor.constraint(equalTo: box.contentView!.bottomAnchor, constant: -10)
        ])
        return box
    }

    public func dashboardDidUpdate(_ snapshot: DashboardSnapshot) {
        cpuGauge.setValue(snapshot.cpu.overallPercent, unit: "%")
        memGauge.setValue(snapshot.memory.usagePercent, unit: "%")
        diskGauge.setValue(snapshot.disk.usagePercent, unit: "%")
        if let b = snapshot.power.batteryPercent {
            batteryGauge.setValue(Double(b), unit: "%")
        } else {
            batteryGauge.setValue(0, unit: "—")
        }

        let topCPU = snapshot.processes
            .sorted { $0.cpuPercent > $1.cpuPercent }
            .prefix(5)
        topCPUText.stringValue = topCPU.map {
            String(format: "%-24s %6.1f%%", ($0.name as NSString).utf8String!, $0.cpuPercent)
        }.joined(separator: "\n")

        let topMem = snapshot.processes
            .sorted { $0.memoryMB > $1.memoryMB }
            .prefix(5)
        topMemText.stringValue = topMem.map {
            String(format: "%-24s %7.1f MB", ($0.name as NSString).utf8String!, $0.memoryMB)
        }.joined(separator: "\n")

        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm:ss"
        timestampLabel.stringValue = "Last updated \(fmt.string(from: snapshot.capturedAt))"
    }
}

final class GaugeView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let valueLabel = NSTextField(labelWithString: "—")
    private var percent: Double = 0

    init(title: String) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.stringValue = title
        valueLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 26, weight: .semibold)

        let stack = NSStackView(views: [titleLabel, valueLabel])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func setValue(_ value: Double, unit: String) {
        percent = value
        if unit == "—" {
            valueLabel.stringValue = "—"
        } else {
            valueLabel.stringValue = String(format: "%.0f%@", value, unit)
        }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let barHeight: CGFloat = 4
        let inset: CGFloat = 12
        let y: CGFloat = inset
        let w = bounds.width - inset * 2
        let bg = NSBezierPath(roundedRect: NSRect(x: inset, y: y, width: w, height: barHeight), xRadius: 2, yRadius: 2)
        NSColor.separatorColor.setFill()
        bg.fill()
        let clamped = max(0, min(100, percent))
        let fw = w * CGFloat(clamped / 100.0)
        if fw > 0 {
            let fill = NSBezierPath(roundedRect: NSRect(x: inset, y: y, width: fw, height: barHeight), xRadius: 2, yRadius: 2)
            NSColor.controlAccentColor.setFill()
            fill.fill()
        }
    }
}
