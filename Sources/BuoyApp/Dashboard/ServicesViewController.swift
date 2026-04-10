import AppKit
import Foundation

public final class ServicesViewController: NSViewController, DashboardConsumer, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    private enum Column {
        static let group = NSUserInterfaceItemIdentifier("group")
        static let label = NSUserInterfaceItemIdentifier("label")
        static let status = NSUserInterfaceItemIdentifier("status")
        static let enabled = NSUserInterfaceItemIdentifier("enabled")
        static let pid = NSUserInterfaceItemIdentifier("pid")
        static let cpu = NSUserInterfaceItemIdentifier("cpu")
        static let mem = NSUserInterfaceItemIdentifier("mem")
        static let location = NSUserInterfaceItemIdentifier("location")
        static let plist = NSUserInterfaceItemIdentifier("plist")
    }

    private let searchField = NSSearchField()
    private let statusFilter = NSPopUpButton(frame: .zero, pullsDown: false)
    private let locationFilter = NSPopUpButton(frame: .zero, pullsDown: false)
    private let summaryLabel = NSTextField(labelWithString: "0 services")
    private let timestampLabel = NSTextField(labelWithString: "—")
    private let table = DashboardTableContainer(columns: [
        (Column.group, "Category", 135),
        (Column.label, "Service", 220),
        (Column.status, "Status", 95),
        (Column.enabled, "Boot", 70),
        (Column.pid, "PID", 75),
        (Column.cpu, "CPU %", 85),
        (Column.mem, "Memory MB", 105),
        (Column.location, "Location", 190),
        (Column.plist, "Plist Path", 360)
    ])

    private var snapshot = DashboardSnapshot()
    private var visibleRows: [ServiceInfoRow] = []

    public override func loadView() {
        view = NSView()
        view.wantsLayer = true
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        buildLayout()
        applyFilters()
    }

    private func buildLayout() {
        searchField.placeholderString = "Search service or plist"
        searchField.delegate = self

        statusFilter.addItems(withTitles: ["All Statuses", "Running", "Stopped", "Disabled"])
        statusFilter.target = self
        statusFilter.action = #selector(filtersChanged)

        locationFilter.addItem(withTitle: "All Locations")
        locationFilter.addItems(withTitles: [
            "System Daemons",
            "System Agents",
            "Library Daemons",
            "Library Agents",
            "User Agents"
        ])
        locationFilter.target = self
        locationFilter.action = #selector(filtersChanged)

        summaryLabel.font = .systemFont(ofSize: 12)
        summaryLabel.textColor = .secondaryLabelColor
        timestampLabel.font = .systemFont(ofSize: 11)
        timestampLabel.textColor = .secondaryLabelColor

        table.tableView.delegate = self
        table.tableView.dataSource = self

        let controls = NSStackView(views: [
            label("Search"), searchField,
            label("Status"), statusFilter,
            label("Location"), locationFilter,
            NSView(),
            summaryLabel,
            timestampLabel
        ])
        controls.orientation = .horizontal
        controls.alignment = .centerY
        controls.spacing = 8

        let stack = NSStackView(views: [controls, table])
        stack.orientation = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20)
        ])
    }

    private func label(_ text: String) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = .systemFont(ofSize: 12)
        field.textColor = .secondaryLabelColor
        return field
    }

    public func dashboardDidUpdate(_ snapshot: DashboardSnapshot) {
        self.snapshot = snapshot
        applyFilters()
        timestampLabel.stringValue = "Last updated \(DashboardFormatters.timestamp(snapshot.capturedAt))"
    }

    @objc private func filtersChanged() {
        applyFilters()
    }

    public func controlTextDidChange(_ obj: Notification) {
        applyFilters()
    }

    private func applyFilters() {
        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let statusTitle = statusFilter.titleOfSelectedItem ?? "All Statuses"
        let locationTitle = locationFilter.titleOfSelectedItem ?? "All Locations"

        visibleRows = snapshot.services.filter { row in
            let matchesQuery = query.isEmpty
                || row.label.localizedCaseInsensitiveContains(query)
                || row.plistPath.localizedCaseInsensitiveContains(query)

            let matchesStatus: Bool
            switch statusTitle {
            case "Running": matchesStatus = row.status == .running
            case "Stopped": matchesStatus = row.status == .stopped
            case "Disabled": matchesStatus = row.status == .disabled
            default: matchesStatus = true
            }

            let matchesLocation: Bool
            switch locationTitle {
            case "System Daemons": matchesLocation = row.location == .systemDaemons
            case "System Agents": matchesLocation = row.location == .systemAgents
            case "Library Daemons": matchesLocation = row.location == .libraryDaemons
            case "Library Agents": matchesLocation = row.location == .libraryAgents
            case "User Agents": matchesLocation = row.location == .userAgents
            default: matchesLocation = true
            }

            return matchesQuery && matchesStatus && matchesLocation
        }

        visibleRows.sort {
            if $0.group == $1.group {
                return $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending
            }
            return $0.group.rawValue.localizedCaseInsensitiveCompare($1.group.rawValue) == .orderedAscending
        }

        summaryLabel.stringValue = "\(visibleRows.count) of \(snapshot.services.count) services"
        table.tableView.reloadData()
    }

    public func numberOfRows(in tableView: NSTableView) -> Int {
        visibleRows.count
    }

    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row >= 0, row < visibleRows.count, let column = tableColumn else { return nil }
        let cell = tableView.makeView(withIdentifier: column.identifier, owner: self) as? NSTableCellView ?? makeCell(identifier: column.identifier)
        cell.textField?.stringValue = displayValue(for: visibleRows[row], column: column.identifier)
        return cell
    }

    private func displayValue(for row: ServiceInfoRow, column: NSUserInterfaceItemIdentifier) -> String {
        switch column {
        case Column.group: return row.group.rawValue
        case Column.label: return row.label
        case Column.status: return row.status.rawValue
        case Column.enabled: return row.enabledOnBoot ? "Yes" : "No"
        case Column.pid: return row.pid.map(String.init) ?? "—"
        case Column.cpu: return DashboardFormatters.percent(row.cpuPercent)
        case Column.mem: return DashboardFormatters.memoryMB(row.memoryMB)
        case Column.location: return String(row.location.rawValue.split(separator: "/").last ?? "")
        case Column.plist: return row.plistPath
        default: return ""
        }
    }

    private func makeCell(identifier: NSUserInterfaceItemIdentifier) -> NSTableCellView {
        let cell = NSTableCellView()
        cell.identifier = identifier
        let textField = NSTextField(labelWithString: "")
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.lineBreakMode = .byTruncatingMiddle
        textField.font = .systemFont(ofSize: 12)
        cell.addSubview(textField)
        cell.textField = textField
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 6),
            textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -6),
            textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])
        return cell
    }
}
