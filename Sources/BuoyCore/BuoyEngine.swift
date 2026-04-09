import Foundation

public final class BuoyEngine {
    public let runner: CommandRunning
    public let stateStore: StateStore
    public let environment: [String: String]
    public let executablePath: String

    public init(
        runner: CommandRunning = SystemCommandRunner(),
        stateStore: StateStore = StateStore(),
        environment: [String: String] = ProcessInfo.processInfo.environment,
        executablePath: String = CommandLine.arguments.first ?? buoyCommandName
    ) {
        self.runner = runner
        self.stateStore = stateStore
        self.environment = environment
        self.executablePath = executablePath
    }

    public func apply(config: BuoyConfig, dryRun: Bool) throws -> [String] {
        try Self.validate(config: config)

        let supportedKeys = try supportedACKeys()
        let currentSettings = try currentACSettings()
        let desiredSettings = PMSetParser.desiredValues(supported: supportedKeys, config: config)

        guard !desiredSettings.isEmpty else {
            throw BuoyError.commandFailed("No supported AC settings were found to manage on this Mac.")
        }

        var state = try stateStore.load() ?? PersistedState()
        if state.originalValues.isEmpty {
            state.originalValues = currentSettings.mapKeys(\.rawValue)
        }
        state.modeEnabled = true
        state.enabledAt = state.enabledAt ?? Self.nowUTC()
        state.config = config
        state.configuredValues = desiredSettings.mapKeys(\.rawValue)

        var messages: [String] = []
        if try currentPowerSource() != "AC Power" {
            messages.append("Warning: You are not currently on AC power. The settings still apply to AC and will take effect when plugged in.")
        }

        if dryRun {
            messages.append("Buoy would be applied with display sleep \(config.displaySleepMinutes) minute(s).")
            messages.append(config.clamEnabled
                ? "Closed-lid awake mode would be enabled while charging or above \(config.clamMinBattery)% battery."
                : "Closed-lid awake mode would be disabled.")
            return messages
        }

        try sudoValidate()
        try setACSettings(desiredSettings)
        try stateStore.save(state)

        if config.clamEnabled {
            let sleepDisabled = try currentSleepDisabled() ?? 0
            state.clamOriginalSleepDisabled = state.clamOriginalSleepDisabled ?? sleepDisabled
            state = try enableClamMonitor(config: config, state: state)
        } else {
            state = try disableClamMonitor(state: state, dryRun: false)
        }

        try stateStore.save(state)

        messages.append("Buoy mode applied.")
        messages.append("Display sleep on AC is set to \(config.displaySleepMinutes) minute(s); full system idle sleep on AC is disabled.")
        messages.append(config.clamEnabled
            ? "Closed-lid awake mode is enabled while charging or above \(config.clamMinBattery)% battery."
            : "Closed-lid awake mode is disabled.")
        return messages
    }

    public func disable(dryRun: Bool) throws -> [String] {
        guard var state = try stateStore.load(), state.modeEnabled else {
            return ["Buoy mode is already off."]
        }

        if dryRun {
            return ["Buoy mode would be disabled and original AC settings restored."]
        }

        try sudoValidate()
        state = try disableClamMonitor(state: state, dryRun: false)
        try setACSettings(Self.restoreSettings(from: state))
        try stateStore.clear()

        return [
            "Buoy mode disabled.",
            "The previously saved AC power settings have been restored."
        ]
    }

    public func status() throws -> BuoyStatus {
        let state = try stateStore.load()
        let monitorRunning = try state?.clamMonitorPID.flatMap(isMonitorRunning(pid:)) ?? false
        let config = state?.config

        return BuoyStatus(
            product: BuoyProductInfo(
                name: buoyProductName,
                version: buoyVersion,
                command: buoyCommandName,
                legacyAlias: buoyLegacyCommandName
            ),
            mode: BuoyModeStatus(
                enabled: state?.modeEnabled ?? false,
                enabledAt: state?.enabledAt,
                displaySleepMinutes: config?.displaySleepMinutes
            ),
            clam: BuoyClamStatus(
                enabled: config?.clamEnabled ?? false,
                minBattery: config?.clamMinBattery,
                pollSeconds: config?.clamPollSeconds,
                monitorPID: state?.clamMonitorPID,
                monitorRunning: monitorRunning
            ),
            system: BuoySystemStatus(
                powerSource: try currentPowerSource(),
                batteryPercent: try currentBatteryPercentage(),
                sleepDisabled: try currentSleepDisabled()
            ),
            paths: BuoyPathStatus(
                stateFile: stateStore.stateFileURL.path
            ),
            managedAC: try currentACSettings().mapKeys(\.rawValue),
            configured: state?.configuredValues ?? [:],
            original: state?.originalValues ?? [:]
        )
    }

    public func doctor() -> DoctorStatus {
        DoctorStatus(
            macOS: true,
            pmset: FileManager.default.isExecutableFile(atPath: "/usr/bin/pmset"),
            osascript: FileManager.default.isExecutableFile(atPath: "/usr/bin/osascript"),
            swift: !(environment["SWIFT_EXEC"] ?? "").isEmpty || FileManager.default.isExecutableFile(atPath: "/usr/bin/swift"),
            xcodebuild: FileManager.default.isExecutableFile(atPath: "/usr/bin/xcodebuild"),
            stateDir: stateStore.stateDirectoryURL.path,
            stateFile: stateStore.stateFileURL.path
        )
    }

    public func screenOff(dryRun: Bool) throws -> [String] {
        if dryRun {
            return [
                "Dry run: pmset displaysleepnow",
                "Display would turn off immediately; moving the mouse or pressing a key will wake it."
            ]
        }

        _ = try runner.run(executable: "/usr/bin/pmset", arguments: ["displaysleepnow"])
        return ["Display sleeping now; move the mouse or press a key to wake it."]
    }

    public func install(targetDirectory: URL, dryRun: Bool) throws -> [String] {
        let fileManager = FileManager.default
        let commandURL = targetDirectory.appendingPathComponent(buoyCommandName)
        let legacyURL = targetDirectory.appendingPathComponent(buoyLegacyCommandName)

        if dryRun {
            return [
                "Dry run: mkdir -p \(targetDirectory.path)",
                "Dry run: copy \(executablePath) to \(commandURL.path)",
                "Dry run: create legacy alias at \(legacyURL.path)"
            ]
        }

        try fileManager.createDirectory(at: targetDirectory, withIntermediateDirectories: true, attributes: nil)
        if fileManager.fileExists(atPath: commandURL.path) {
            try fileManager.removeItem(at: commandURL)
        }
        try fileManager.copyItem(at: URL(fileURLWithPath: executablePath), to: commandURL)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: commandURL.path)

        if fileManager.fileExists(atPath: legacyURL.path) {
            try fileManager.removeItem(at: legacyURL)
        }
        try fileManager.createSymbolicLink(at: legacyURL, withDestinationURL: commandURL)

        return [
            "Installed CLI at \(commandURL.path)",
            "Installed legacy alias at \(legacyURL.path)"
        ]
    }

    public func appendProjectToPATH(dryRun: Bool) throws -> [String] {
        let projectRoot = URL(fileURLWithPath: executablePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let line = #"export PATH="$PATH:\#(projectRoot.path)""#
        let rcFile = ShellProfiles.rcFile()

        if let existing = try? String(contentsOf: rcFile, encoding: .utf8), existing.contains(projectRoot.path) {
            return ["PATH already contains \(projectRoot.path) in \(rcFile.path)."]
        }

        if dryRun {
            return ["Dry run: append '\(line)' to \(rcFile.path)"]
        }

        let block = "\n# buoy path\n\(line)\n"
        if FileManager.default.fileExists(atPath: rcFile.path) {
            let handle = try FileHandle(forWritingTo: rcFile)
            try handle.seekToEnd()
            handle.write(Data(block.utf8))
            try handle.close()
        } else {
            try block.write(to: rcFile, atomically: true, encoding: .utf8)
        }

        return ["Appended \(projectRoot.path) to PATH in \(rcFile.path). Restart or source that file."]
    }

    public func runClamMonitor(stateFilePath: String, minBattery: Int, pollSeconds: Int) throws {
        try Self.validateClam(minBattery: minBattery, pollSeconds: pollSeconds)
        let monitorStore = StateStore(
            stateFileURL: URL(fileURLWithPath: stateFilePath),
            legacyStateFileURL: stateStore.legacyStateFileURL
        )

        while true {
            guard let state = try monitorStore.load(), state.modeEnabled, let config = state.config, config.clamEnabled else {
                exit(0)
            }

            let desired = try desiredSleepDisabled(minBattery: minBattery, originalSleepDisabled: state.clamOriginalSleepDisabled ?? 0)
            let current = try currentSleepDisabled()
            if current != desired {
                _ = try runner.run(executable: "/usr/bin/pmset", arguments: ["disablesleep", "\(desired)"])
            }
            Thread.sleep(forTimeInterval: TimeInterval(pollSeconds))
        }
    }

    private func supportedACKeys() throws -> Set<BuoyPowerKey> {
        let output = try runner.run(executable: "/usr/bin/pmset", arguments: ["-g", "cap"])
        return PMSetParser.parseCapabilities(output.stdout)
    }

    private func currentACSettings() throws -> [BuoyPowerKey: Int] {
        let output = try runner.run(executable: "/usr/bin/pmset", arguments: ["-g", "custom"])
        return PMSetParser.parseCustomSettings(output.stdout)
    }

    private func currentPowerSource() throws -> String {
        let output = try runner.run(executable: "/usr/bin/pmset", arguments: ["-g", "batt"])
        return PMSetParser.currentPowerSource(output.stdout)
    }

    private func currentBatteryPercentage() throws -> Int? {
        let output = try runner.run(executable: "/usr/bin/pmset", arguments: ["-g", "batt"])
        return PMSetParser.currentBatteryPercentage(output.stdout)
    }

    private func currentSleepDisabled() throws -> Int? {
        let output = try runner.run(executable: "/usr/bin/pmset", arguments: ["-g"])
        return PMSetParser.currentSleepDisabled(output.stdout)
    }

    private func sudoValidate() throws {
        _ = try runner.run(executable: "/usr/bin/sudo", arguments: ["-v"], interactive: true)
    }

    private func setACSettings(_ values: [BuoyPowerKey: Int]) throws {
        var arguments = ["pmset", "-c"]
        for key in BuoyPowerKey.allCases {
            guard let value = values[key] else { continue }
            arguments.append(key.rawValue)
            arguments.append(String(value))
        }
        _ = try runner.run(executable: "/usr/bin/sudo", arguments: arguments, interactive: true)
    }

    private func enableClamMonitor(config: BuoyConfig, state: PersistedState) throws -> PersistedState {
        var newState = state
        let desired = try desiredSleepDisabled(
            minBattery: config.clamMinBattery,
            originalSleepDisabled: newState.clamOriginalSleepDisabled ?? 0
        )
        _ = try runner.run(executable: "/usr/bin/sudo", arguments: ["pmset", "disablesleep", "\(desired)"], interactive: true)

        if let existingPID = newState.clamMonitorPID, try isMonitorRunning(pid: existingPID) {
            _ = try runner.run(executable: "/usr/bin/sudo", arguments: ["kill", "\(existingPID)"], interactive: true)
        }

        let pid = try runner.runDetached(
            executable: "/usr/bin/sudo",
            arguments: [
                "env",
                "BUOY_STATE_DIR=\(stateStore.stateDirectoryURL.path)",
                "HEALTHYSERVERMAC_STATE_DIR=\(stateStore.stateDirectoryURL.path)",
                executablePath,
                "__clam-monitor",
                stateStore.stateFileURL.path,
                String(config.clamMinBattery),
                String(config.clamPollSeconds)
            ],
            environment: nil
        )
        newState.clamMonitorPID = Int(pid)
        return newState
    }

    private func disableClamMonitor(state: PersistedState, dryRun: Bool) throws -> PersistedState {
        var newState = state
        if let monitorPID = newState.clamMonitorPID, try isMonitorRunning(pid: monitorPID), !dryRun {
            _ = try runner.run(executable: "/usr/bin/sudo", arguments: ["kill", "\(monitorPID)"], interactive: true)
        }
        if let original = newState.clamOriginalSleepDisabled, !dryRun {
            _ = try runner.run(executable: "/usr/bin/sudo", arguments: ["pmset", "disablesleep", "\(original)"], interactive: true)
        }
        newState.clamMonitorPID = nil
        newState.clamOriginalSleepDisabled = nil
        if var config = newState.config {
            config.clamEnabled = false
            newState.config = config
        }
        return newState
    }

    private func desiredSleepDisabled(minBattery: Int, originalSleepDisabled: Int) throws -> Int {
        if originalSleepDisabled == 1 {
            return 1
        }
        if try currentPowerSource() == "AC Power" {
            return 1
        }
        let battery = try currentBatteryPercentage() ?? 0
        return battery > minBattery ? 1 : 0
    }

    private func isMonitorRunning(pid: Int) throws -> Bool {
        let output = try runner.run(
            executable: "/bin/ps",
            arguments: ["-p", "\(pid)", "-o", "command="],
            allowNonZeroExit: true
        )
        return output.exitCode == 0 && output.stdout.contains("__clam-monitor")
    }

    private static func restoreSettings(from state: PersistedState) -> [BuoyPowerKey: Int] {
        var values: [BuoyPowerKey: Int] = [:]
        for key in BuoyPowerKey.allCases {
            if let value = state.originalValues[key.rawValue] {
                values[key] = value
            }
        }
        return values
    }

    private static func validate(config: BuoyConfig) throws {
        guard (1...180).contains(config.displaySleepMinutes) else {
            throw BuoyError.invalidArgument("Display sleep must be between 1 and 180 minutes.")
        }
        try validateClam(minBattery: config.clamMinBattery, pollSeconds: config.clamPollSeconds)
    }

    private static func validateClam(minBattery: Int, pollSeconds: Int) throws {
        guard (0...100).contains(minBattery) else {
            throw BuoyError.invalidArgument("Closed-lid battery threshold must be between 0 and 100.")
        }
        guard (5...3600).contains(pollSeconds) else {
            throw BuoyError.invalidArgument("Closed-lid poll interval must be between 5 and 3600 seconds.")
        }
    }

    private static func nowUTC() -> String {
        ISO8601DateFormatter().string(from: Date())
    }
}

private extension Dictionary where Key == BuoyPowerKey, Value == Int {
    func mapKeys<T: Hashable>(_ transform: (BuoyPowerKey) -> T) -> [T: Int] {
        reduce(into: [T: Int]()) { partialResult, element in
            partialResult[transform(element.key)] = element.value
        }
    }
}
