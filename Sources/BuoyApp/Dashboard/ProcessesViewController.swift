import AppKit
import Foundation

public final class ProcessesViewController: NSViewController, DashboardConsumer, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    private enum Column {
        static let name = NSUserInterfaceItemIdentifier("name")
        static let pid = NSUserInterfaceItemIdentifier("pid")
        static let ppid = NSUserInterfaceItemIdentifier("ppid")
        static let cpu = NSUserInterfaceItemIdentifier("cpu")
        static let memMB = NSUserInterfaceItemIdentifier("memMB")
        static let memPct = NSUserInterfaceItemIdentifier("memPct")
        static let state = NSUserInterfaceItemIdentifier("state")
        static let user = NSUserInterfaceItemIdentifier("user")
    }

    private let searchField = NSSearchField()
    private let userFilter = NSPopUpButton(frame: .zero, pullsDown: false)
    private let sortPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let summaryLabel = NSTextField(labelWithString: "0 processes")
    private let timestampLabel = NSTextField(labelWithString: "—")
    private let table = DashboardTableContainer(columns: [
        (Column.name, "Process", 240),
        (Column.pid, "PID", 80),
        (Column.ppid, "PPID", 80),
        (Column.cpu, "CPU %", 90),
        (Column.memMB, "Memory MB", 110),
        (Column.memPct, "Memory %", 95),
        (Column.state, "State", 110),
        (Column.user, "User", 120)
    ])

    private var snapshot = DashboardSnapshot()
    private var visibleRows: [ProcessInfoRow] = []

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
        searchField.placeholderString = "Search process name"
        searchField.delegate = self

        sortPopup.addItems(withTitles: ProcessSortKey.allCases.map(\.rawValue))
        sortPopup.selectItem(withTitle: ProcessSortKey.cpu.rawValue)
        sortPopup.target = self
        sortPopup.action = #selector(filtersChanged)

        userFilter.target = self
        userFilter.action = #selector(filtersChanged)

        summaryLabel.font = .systemFont(ofSize: 12)
        summaryLabel.textColor = .secondaryLabelColor
        timestampLabel.font = .systemFont(ofSize: 11)
        timestampLabel.textColor = .secondaryLabelColor

        table.tableView.delegate = self
        table.tableView.dataSource = self

        let controls = NSStackView(views: [
            label("Search"), searchField,
            label("User"), userFilter,
            label("Sort"), sortPopup,
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
        refreshUserChoices()
        applyFilters()
        timestampLabel.stringValue = "Last updated \(DashboardFormatters.timestamp(snapshot.capturedAt))"
    }

    private func refreshUserChoices() {
        let selected = userFilter.titleOfSelectedItem ?? "All Users"
        let users = Array(Set(snapshot.processes.map(\.user))).sorted()
        userFilter.removeAllItems()
        userFilter.addItem(withTitle: "All Users")
        userFilter.addItems(withTitles: users)
        if userFilter.itemTitles.contains(selected) {
            userFilter.selectItem(withTitle: selected)
        } else {
            userFilter.selectItem(at: 0)
        }
    }

    @objc private func filtersChanged() {
        applyFilters()
    }

    public func controlTextDidChange(_ obj: Notification) {
        applyFilters()
    }

    private func applyFilters() {
        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let selectedUser = userFilter.titleOfSelectedItem ?? "All Users"
        let sortKey = ProcessSortKey(rawValue: sortPopup.titleOfSelectedItem ?? "") ?? .cpu

        visibleRows = snapshot.processes.filter { row in
            let matchesName = query.isEmpty || row.name.localizedCaseInsensitiveContains(query)
            let matchesUser = selectedUser == "All Users" || row.user == selectedUser
            return matchesName && matchesUser
        }

        visibleRows.sort { lhs, rhs in
            switch sortKey {
            case .cpu:
                return lhs.cpuPercent == rhs.cpuPercent ? lhs.pid < rhs.pid : lhs.cpuPercent > rhs.cpuPercent
            case .memory:
                return lhs.memoryPercent == rhs.memoryPercent ? lhs.pid < rhs.pid : lhs.memoryPercent > rhs.memoryPercent
            case .pid:
                return lhs.pid < rhs.pid
            case .name:
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            case .user:
                if lhs.user == rhs.user {
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                return lhs.user.localizedCaseInsensitiveCompare(rhs.user) == .orderedAscending
            }
        }

        summaryLabel.stringValue = "\(visibleRows.count) of \(snapshot.processes.count) processes"
        table.tableView.reloadData()
    }

    public func numberOfRows(in tableView: NSTableView) -> Int {
        visibleRows.count
    }

    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row >= 0, row < visibleRows.count, let column = tableColumn else { return nil }
        let value = displayValue(for: visibleRows[row], column: column.identifier)
        let identifier = column.identifier
        let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView ?? makeCell(identifier: identifier)
        cell.textField?.stringValue = value
        return cell
    }

    private func displayValue(for row: ProcessInfoRow, column: NSUserInterfaceItemIdentifier) -> String {
        switch column {
        case Column.name: return row.name
        case Column.pid: return "\(row.pid)"
        case Column.ppid: return "\(row.ppid)"
        case Column.cpu: return DashboardFormatters.percent(row.cpuPercent)
        case Column.memMB: return DashboardFormatters.memoryMB(row.memoryMB)
        case Column.memPct: return DashboardFormatters.percent(row.memoryPercent)
        case Column.state: return row.state
        case Column.user: return row.user
        default: return ""
        }
    }

    private func makeCell(identifier: NSUserInterfaceItemIdentifier) -> NSTableCellView {
        let cell = NSTableCellView()
        cell.identifier = identifier
        let textField = NSTextField(labelWithString: "")
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.lineBreakMode = .byTruncatingMiddle
        if identifier == Column.pid || identifier == Column.ppid || identifier == Column.cpu || identifier == Column.memMB || identifier == Column.memPct {
            textField.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        } else {
            textField.font = .systemFont(ofSize: 12)
        }
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
