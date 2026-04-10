import AppKit
import Foundation

final class DashboardSectionView: NSBox {
    init(title: String) {
        super.init(frame: .zero)
        boxType = .custom
        cornerRadius = 12
        borderWidth = 1
        borderColor = .separatorColor
        fillColor = .controlBackgroundColor
        titlePosition = .noTitle

        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView?.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: contentView!.leadingAnchor, constant: 14),
            label.topAnchor.constraint(equalTo: contentView!.topAnchor, constant: 12)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func pinContent(_ child: NSView, top: CGFloat = 34, bottom: CGFloat = 14) {
        child.translatesAutoresizingMaskIntoConstraints = false
        contentView?.addSubview(child)
        NSLayoutConstraint.activate([
            child.leadingAnchor.constraint(equalTo: contentView!.leadingAnchor, constant: 14),
            child.trailingAnchor.constraint(equalTo: contentView!.trailingAnchor, constant: -14),
            child.topAnchor.constraint(equalTo: contentView!.topAnchor, constant: top),
            child.bottomAnchor.constraint(equalTo: contentView!.bottomAnchor, constant: -bottom)
        ])
    }
}

final class DashboardTableContainer: NSView {
    let tableView = NSTableView()
    let scrollView = NSScrollView()

    init(columns: [(id: NSUserInterfaceItemIdentifier, title: String, width: CGFloat)]) {
        super.init(frame: .zero)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.borderType = .bezelBorder
        addSubview(scrollView)

        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsEmptySelection = true
        tableView.rowSizeStyle = .default
        tableView.headerView = NSTableHeaderView()

        for column in columns {
            let tableColumn = NSTableColumn(identifier: column.id)
            tableColumn.title = column.title
            tableColumn.width = column.width
            tableColumn.minWidth = min(column.width, 80)
            tableView.addTableColumn(tableColumn)
        }

        scrollView.documentView = tableView

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
}

enum DashboardFormatters {
    static func percent(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.1f%%", value)
    }

    static func number(_ value: Double?, unit: String, decimals: Int = 1) -> String {
        guard let value else { return "—" }
        return String(format: "%.\(decimals)f %@", value, unit)
    }

    static func memoryMB(_ value: Double?) -> String {
        number(value, unit: "MB", decimals: 1)
    }

    static func duration(minutes: Int?) -> String {
        guard let minutes, minutes >= 0 else { return "—" }
        let hours = minutes / 60
        let mins = minutes % 60
        return String(format: "%d:%02d", hours, mins)
    }

    static func timestamp(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm:ss"
        return fmt.string(from: date)
    }
}
