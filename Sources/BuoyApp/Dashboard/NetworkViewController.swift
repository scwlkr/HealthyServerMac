import AppKit
import Foundation

public final class NetworkViewController: NSViewController, DashboardConsumer, NSTableViewDataSource, NSTableViewDelegate {
    private enum PortColumn {
        static let service = NSUserInterfaceItemIdentifier("service")
        static let proto = NSUserInterfaceItemIdentifier("proto")
        static let port = NSUserInterfaceItemIdentifier("port")
        static let local = NSUserInterfaceItemIdentifier("local")
        static let owner = NSUserInterfaceItemIdentifier("owner")
        static let pid = NSUserInterfaceItemIdentifier("pid")
    }

    private enum InterfaceColumn {
        static let name = NSUserInterfaceItemIdentifier("name")
        static let ipv4 = NSUserInterfaceItemIdentifier("ipv4")
        static let ipv6 = NSUserInterfaceItemIdentifier("ipv6")
        static let mac = NSUserInterfaceItemIdentifier("mac")
        static let status = NSUserInterfaceItemIdentifier("status")
    }

    private let summaryLabel = NSTextField(labelWithString: "0 listeners • 0 interfaces")
    private let timestampLabel = NSTextField(labelWithString: "—")
    private let portsTable = DashboardTableContainer(columns: [
        (PortColumn.service, "Service", 160),
        (PortColumn.proto, "Proto", 80),
        (PortColumn.port, "Port", 80),
        (PortColumn.local, "Local Address", 220),
        (PortColumn.owner, "Process/Owner", 180),
        (PortColumn.pid, "PID", 80)
    ])
    private let interfacesTable = DashboardTableContainer(columns: [
        (InterfaceColumn.name, "Interface", 100),
        (InterfaceColumn.ipv4, "IPv4", 220),
        (InterfaceColumn.ipv6, "IPv6", 260),
        (InterfaceColumn.mac, "MAC", 150),
        (InterfaceColumn.status, "Status", 100)
    ])

    private var snapshot = DashboardSnapshot()

    public override func loadView() {
        view = NSView()
        view.wantsLayer = true
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        buildLayout()
    }

    private func buildLayout() {
        summaryLabel.font = .systemFont(ofSize: 12)
        summaryLabel.textColor = .secondaryLabelColor
        timestampLabel.font = .systemFont(ofSize: 11)
        timestampLabel.textColor = .secondaryLabelColor

        portsTable.tableView.delegate = self
        portsTable.tableView.dataSource = self
        interfacesTable.tableView.delegate = self
        interfacesTable.tableView.dataSource = self

        let topBar = NSStackView(views: [summaryLabel, NSView(), timestampLabel])
        topBar.orientation = .horizontal
        topBar.alignment = .centerY

        let listenersSection = DashboardSectionView(title: "Listening Services")
        listenersSection.pinContent(portsTable)

        let interfacesSection = DashboardSectionView(title: "Network Interfaces")
        interfacesSection.pinContent(interfacesTable)

        let stack = NSStackView(views: [topBar, listenersSection, interfacesSection])
        stack.orientation = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            listenersSection.heightAnchor.constraint(greaterThanOrEqualToConstant: 240),
            interfacesSection.heightAnchor.constraint(greaterThanOrEqualToConstant: 220)
        ])
    }

    public func dashboardDidUpdate(_ snapshot: DashboardSnapshot) {
        self.snapshot = snapshot
        summaryLabel.stringValue = "\(snapshot.network.listeningPorts.count) listeners • \(snapshot.network.interfaces.count) interfaces"
        timestampLabel.stringValue = "Last updated \(DashboardFormatters.timestamp(snapshot.capturedAt))"
        portsTable.tableView.reloadData()
        interfacesTable.tableView.reloadData()
    }

    public func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView === portsTable.tableView {
            return snapshot.network.listeningPorts.count
        }
        return snapshot.network.interfaces.count
    }

    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let column = tableColumn else { return nil }
        let cell = tableView.makeView(withIdentifier: column.identifier, owner: self) as? NSTableCellView ?? makeCell(identifier: column.identifier)

        if tableView === portsTable.tableView {
            let item = snapshot.network.listeningPorts[row]
            cell.textField?.stringValue = portValue(item, column: column.identifier)
        } else {
            let item = snapshot.network.interfaces[row]
            cell.textField?.stringValue = interfaceValue(item, column: column.identifier)
        }
        return cell
    }

    private func portValue(_ row: ListeningPort, column: NSUserInterfaceItemIdentifier) -> String {
        switch column {
        case PortColumn.service: return row.service
        case PortColumn.proto: return row.proto
        case PortColumn.port: return "\(row.port)"
        case PortColumn.local: return row.localAddress
        case PortColumn.owner: return row.owner
        case PortColumn.pid: return row.pid.map(String.init) ?? "—"
        default: return ""
        }
    }

    private func interfaceValue(_ row: NetworkInterfaceInfo, column: NSUserInterfaceItemIdentifier) -> String {
        switch column {
        case InterfaceColumn.name: return row.name
        case InterfaceColumn.ipv4: return row.ipv4.joined(separator: ", ")
        case InterfaceColumn.ipv6: return row.ipv6.joined(separator: ", ")
        case InterfaceColumn.mac: return row.mac ?? "—"
        case InterfaceColumn.status: return row.isUp ? "Active" : "Inactive"
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
