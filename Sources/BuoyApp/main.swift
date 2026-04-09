import AppKit
import Foundation

enum AppearanceMode: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
}

@main
final class BuoyAppDelegate: NSObject, NSApplicationDelegate {
    private var controller: BuoyWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        controller = BuoyWindowController()
        controller?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

final class BuoyWindowController: NSWindowController {
    private let bridge = ShellBridge()
    private let contentController = BuoyViewController()

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 610),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = buoyProductName
        window.center()
        window.isReleasedWhenClosed = false
        window.contentViewController = contentController
        super.init(window: window)
        contentController.bridge = bridge
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class BuoyViewController: NSViewController {
    var bridge: ShellBridge?

    private let titleLabel = NSTextField(labelWithString: buoyProductName)
    private let subtitleLabel = NSTextField(labelWithString: "Keep this Mac server-ready while plugged in.")

    private lazy var enabledSwitch = makeSwitch(title: "Server mode")
    private lazy var clamSwitch = makeSwitch(title: "Closed-lid awake")
    private let displaySleepSlider = NSSlider(value: 10, minValue: 1, maxValue: 60, target: nil, action: nil)
    private let displaySleepValue = NSTextField(labelWithString: "10 min")
    private let batterySlider = NSSlider(value: 25, minValue: 0, maxValue: 100, target: nil, action: nil)
    private let batteryValue = NSTextField(labelWithString: "25%")
    private let pollSlider = NSSlider(value: 20, minValue: 5, maxValue: 120, target: nil, action: nil)
    private let pollValue = NSTextField(labelWithString: "20 sec")
    private let appearancePopup = NSPopUpButton(frame: .zero, pullsDown: false)

    private lazy var applyButton = makeButton(title: "Apply", action: #selector(applyPressed))
    private lazy var turnOffButton = makeButton(title: "Turn Off", action: #selector(turnOffPressed))
    private lazy var screenOffButton = makeButton(title: "Sleep Display", action: #selector(screenOffPressed))
    private lazy var refreshButton = makeButton(title: "Refresh", action: #selector(refreshPressed))

    private let statusLabel = NSTextField(wrappingLabelWithString: "Loading status...")
    private let footerLabel = NSTextField(wrappingLabelWithString: "Buoy uses the CLI under the hood, so every action stays scriptable.")

    private var isBusy = false {
        didSet { updateBusyState() }
    }

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor(calibratedWhite: 0.98, alpha: 1.0).cgColor
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureAppearance()
        buildLayout()
        wireActions()
        refreshStatus()
    }

    private func configureAppearance() {
        titleLabel.font = NSFont.systemFont(ofSize: 28, weight: .semibold)
        titleLabel.textColor = NSColor(calibratedRed: 0.08, green: 0.14, blue: 0.20, alpha: 1.0)

        subtitleLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor

        footerLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        footerLabel.textColor = .secondaryLabelColor

        statusLabel.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        statusLabel.maximumNumberOfLines = 0
        statusLabel.textColor = NSColor(calibratedRed: 0.12, green: 0.18, blue: 0.23, alpha: 1.0)

        appearancePopup.addItems(withTitles: AppearanceMode.allCases.map(\.rawValue))
        appearancePopup.selectItem(withTitle: UserDefaults.standard.string(forKey: "appearance_mode") ?? AppearanceMode.system.rawValue)
        applyAppearance()
    }

    private func buildLayout() {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -24)
        ])

        let headerStack = NSStackView(views: [titleLabel, subtitleLabel])
        headerStack.orientation = .vertical
        headerStack.spacing = 6

        let panel = makePanel()
        let panelStack = NSStackView()
        panelStack.orientation = .vertical
        panelStack.spacing = 14
        panelStack.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView?.addSubview(panelStack)
        NSLayoutConstraint.activate([
            panelStack.leadingAnchor.constraint(equalTo: panel.contentView!.leadingAnchor, constant: 18),
            panelStack.trailingAnchor.constraint(equalTo: panel.contentView!.trailingAnchor, constant: -18),
            panelStack.topAnchor.constraint(equalTo: panel.contentView!.topAnchor, constant: 18),
            panelStack.bottomAnchor.constraint(equalTo: panel.contentView!.bottomAnchor, constant: -18)
        ])

        panelStack.addArrangedSubview(enabledSwitch)
        panelStack.addArrangedSubview(clamSwitch)
        panelStack.addArrangedSubview(makeSliderRow(title: "Display sleep", slider: displaySleepSlider, valueLabel: displaySleepValue))
        panelStack.addArrangedSubview(makeSliderRow(title: "Battery floor", slider: batterySlider, valueLabel: batteryValue))
        panelStack.addArrangedSubview(makeSliderRow(title: "Poll interval", slider: pollSlider, valueLabel: pollValue))
        panelStack.addArrangedSubview(makeAppearanceRow())
        panelStack.addArrangedSubview(makeButtonRow())

        let statusPanel = makePanel()
        let statusStack = NSStackView(views: [statusLabel])
        statusStack.orientation = .vertical
        statusStack.translatesAutoresizingMaskIntoConstraints = false
        statusPanel.contentView?.addSubview(statusStack)
        NSLayoutConstraint.activate([
            statusStack.leadingAnchor.constraint(equalTo: statusPanel.contentView!.leadingAnchor, constant: 18),
            statusStack.trailingAnchor.constraint(equalTo: statusPanel.contentView!.trailingAnchor, constant: -18),
            statusStack.topAnchor.constraint(equalTo: statusPanel.contentView!.topAnchor, constant: 18),
            statusStack.bottomAnchor.constraint(equalTo: statusPanel.contentView!.bottomAnchor, constant: -18)
        ])

        stack.addArrangedSubview(headerStack)
        stack.addArrangedSubview(panel)
        stack.addArrangedSubview(statusPanel)
        stack.addArrangedSubview(footerLabel)
    }

    private func wireActions() {
        displaySleepSlider.target = self
        displaySleepSlider.action = #selector(sliderChanged(_:))
        batterySlider.target = self
        batterySlider.action = #selector(sliderChanged(_:))
        pollSlider.target = self
        pollSlider.action = #selector(sliderChanged(_:))
        appearancePopup.target = self
        appearancePopup.action = #selector(appearanceChanged)
        enabledSwitch.target = self
        enabledSwitch.action = #selector(enabledChanged)
        clamSwitch.target = self
        clamSwitch.action = #selector(enabledChanged)

        updateSliderLabels()
        updateBusyState()
    }

    private func makePanel() -> NSBox {
        let box = NSBox()
        box.boxType = .custom
        box.cornerRadius = 14
        box.borderWidth = 1
        box.borderColor = NSColor(calibratedWhite: 0.87, alpha: 1.0)
        box.fillColor = .white
        box.contentViewMargins = NSSize(width: 0, height: 0)
        return box
    }

    private func makeSwitch(title: String) -> NSButton {
        let button = NSButton(checkboxWithTitle: title, target: nil, action: nil)
        button.setButtonType(.switch)
        button.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        return button
    }

    private func makeButton(title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        return button
    }

    private func makeSliderRow(title: String, slider: NSSlider, valueLabel: NSTextField) -> NSView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        valueLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        valueLabel.alignment = .right
        valueLabel.textColor = .secondaryLabelColor

        let header = NSStackView(views: [titleLabel, NSView(), valueLabel])
        header.orientation = .horizontal
        header.distribution = .fill

        let stack = NSStackView(views: [header, slider])
        stack.orientation = .vertical
        stack.spacing = 8
        return stack
    }

    private func makeAppearanceRow() -> NSView {
        let title = NSTextField(labelWithString: "Appearance")
        title.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        let stack = NSStackView(views: [title, NSView(), appearancePopup])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        return stack
    }

    private func makeButtonRow() -> NSView {
        let stack = NSStackView(views: [applyButton, turnOffButton, screenOffButton, NSView(), refreshButton])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 10
        return stack
    }

    private func updateSliderLabels() {
        displaySleepValue.stringValue = "\(Int(displaySleepSlider.doubleValue)) min"
        batteryValue.stringValue = "\(Int(batterySlider.doubleValue))%"
        pollValue.stringValue = "\(Int(pollSlider.doubleValue)) sec"
    }

    private func updateBusyState() {
        let controls: [NSControl] = [
            enabledSwitch, clamSwitch, displaySleepSlider, batterySlider, pollSlider,
            appearancePopup, applyButton, turnOffButton, screenOffButton, refreshButton
        ]
        controls.forEach { $0.isEnabled = !isBusy }
    }

    @objc
    private func sliderChanged(_ sender: NSSlider) {
        updateSliderLabels()
    }

    @objc
    private func enabledChanged() {
        clamSwitch.isEnabled = enabledSwitch.state == .on
    }

    @objc
    private func appearanceChanged() {
        UserDefaults.standard.set(appearancePopup.titleOfSelectedItem ?? AppearanceMode.system.rawValue, forKey: "appearance_mode")
        applyAppearance()
    }

    private func applyAppearance() {
        guard let selected = appearancePopup.titleOfSelectedItem, let mode = AppearanceMode(rawValue: selected) else { return }
        switch mode {
        case .system:
            view.window?.appearance = nil
            NSApp.appearance = nil
        case .light:
            let appearance = NSAppearance(named: .aqua)
            view.window?.appearance = appearance
            NSApp.appearance = appearance
        case .dark:
            let appearance = NSAppearance(named: .darkAqua)
            view.window?.appearance = appearance
            NSApp.appearance = appearance
        }
    }

    @objc
    private func applyPressed() {
        guard let bridge else { return }
        isBusy = true

        if enabledSwitch.state == .off {
            bridge.runPrivileged(arguments: ["off"]) { [weak self] result in
                DispatchQueue.main.async {
                    self?.handleCommandResult(result)
                }
            }
            return
        }

        var arguments = [
            "apply",
            "--display-sleep", "\(Int(displaySleepSlider.doubleValue))",
            "--clam-min-battery", "\(Int(batterySlider.doubleValue))",
            "--clam-poll-seconds", "\(Int(pollSlider.doubleValue))"
        ]
        if clamSwitch.state == .on {
            arguments.append("--clam")
        }

        bridge.runPrivileged(arguments: arguments) { [weak self] result in
            DispatchQueue.main.async {
                self?.handleCommandResult(result)
            }
        }
    }

    @objc
    private func turnOffPressed() {
        guard let bridge else { return }
        isBusy = true
        bridge.runPrivileged(arguments: ["off"]) { [weak self] result in
            DispatchQueue.main.async {
                self?.handleCommandResult(result)
            }
        }
    }

    @objc
    private func screenOffPressed() {
        guard let bridge else { return }
        isBusy = true
        bridge.run(arguments: ["screen-off"]) { [weak self] result in
            DispatchQueue.main.async {
                self?.handleCommandResult(result)
            }
        }
    }

    @objc
    private func refreshPressed() {
        refreshStatus()
    }

    private func refreshStatus() {
        guard let bridge else { return }
        isBusy = true
        bridge.fetchStatus { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isBusy = false
                switch result {
                case .success(let status):
                    self.render(status: status)
                case .failure(let error):
                    self.statusLabel.stringValue = "Status unavailable.\n\(error.localizedDescription)"
                }
            }
        }
    }

    private func render(status: BuoyStatus) {
        enabledSwitch.state = status.mode.enabled ? .on : .off
        clamSwitch.state = status.clam.enabled ? .on : .off
        clamSwitch.isEnabled = status.mode.enabled
        displaySleepSlider.doubleValue = Double(status.mode.displaySleepMinutes ?? 10)
        batterySlider.doubleValue = Double(status.clam.minBattery ?? 25)
        pollSlider.doubleValue = Double(status.clam.pollSeconds ?? 20)
        updateSliderLabels()

        var lines: [String] = []
        lines.append("power       \(status.system.powerSource)")
        if let battery = status.system.batteryPercent {
            lines.append("battery     \(battery)%")
        }
        if let sleepDisabled = status.system.sleepDisabled {
            lines.append("lid guard   \(sleepDisabled == 1 ? "awake" : "normal")")
        }
        lines.append("mode        \(status.mode.enabled ? "enabled" : "disabled")")
        if let displaySleep = status.mode.displaySleepMinutes {
            lines.append("display     \(displaySleep) min")
        }
        if status.clam.enabled {
            lines.append("closed lid  on")
            if let pid = status.clam.monitorPID {
                lines.append("monitor     \(status.clam.monitorRunning ? "pid \(pid)" : "stopped")")
            }
        } else {
            lines.append("closed lid  off")
        }
        statusLabel.stringValue = lines.joined(separator: "\n")
    }

    private func handleCommandResult(_ result: Result<String, Error>) {
        isBusy = false
        switch result {
        case .success(let output):
            if !output.isEmpty {
                statusLabel.stringValue = output
            }
            refreshStatus()
        case .failure(let error):
            statusLabel.stringValue = "Command failed.\n\(error.localizedDescription)"
        }
    }
}

final class ShellBridge {
    private let queue = DispatchQueue(label: "buoy.shell", qos: .userInitiated)

    func fetchStatus(completion: @escaping (Result<BuoyStatus, Error>) -> Void) {
        run(arguments: ["status", "--json"]) { result in
            switch result {
            case .success(let output):
                do {
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    let status = try decoder.decode(BuoyStatus.self, from: Data(output.utf8))
                    completion(.success(status))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func run(arguments: [String], completion: @escaping (Result<String, Error>) -> Void) {
        queue.async {
            do {
                let output = try self.execute(arguments: arguments)
                completion(.success(output))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func runPrivileged(arguments: [String], completion: @escaping (Result<String, Error>) -> Void) {
        queue.async {
            do {
                let output = try self.executePrivileged(arguments: arguments)
                completion(.success(output))
            } catch {
                completion(.failure(error))
            }
        }
    }

    private func execute(arguments: [String]) throws -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: resolvedCLIPath())
        task.arguments = arguments
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = errorPipe
        try task.run()
        task.waitUntilExit()

        let stdout = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        guard task.terminationStatus == 0 else {
            throw BuoyError.commandFailed(stderr.isEmpty ? stdout : stderr)
        }

        return stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func executePrivileged(arguments: [String]) throws -> String {
        let command = ([resolvedCLIPath()] + arguments).map(shellEscape(_:)).joined(separator: " ")
        let script = #"do shell script "\#(appleScriptEscape(command))" with administrator privileges"#

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = errorPipe
        try task.run()
        task.waitUntilExit()

        let stdout = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        guard task.terminationStatus == 0 else {
            throw BuoyError.commandFailed(stderr.isEmpty ? stdout : stderr)
        }

        return stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func resolvedCLIPath() -> String {
        let fileManager = FileManager.default

        if let bundled = Bundle.main.path(forResource: buoyCommandName, ofType: nil, inDirectory: "bin") {
            return bundled
        }

        let candidates = [
            "/usr/local/bin/\(buoyCommandName)",
            "\(NSHomeDirectory())/.local/bin/\(buoyCommandName)",
            "/opt/homebrew/bin/\(buoyCommandName)"
        ]

        if let first = candidates.first(where: { fileManager.isExecutableFile(atPath: $0) }) {
            return first
        }

        return buoyCommandName
    }

    private func shellEscape(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private func appleScriptEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
