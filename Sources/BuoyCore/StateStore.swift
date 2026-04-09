import Foundation

public final class StateStore {
    public let stateFileURL: URL
    public let legacyStateFileURL: URL

    private let fileManager: FileManager

    public init(
        stateFileURL: URL = BuoyPaths.stateFileURL(),
        legacyStateFileURL: URL = BuoyPaths.legacyStateFileURL(),
        fileManager: FileManager = .default
    ) {
        self.stateFileURL = stateFileURL
        self.legacyStateFileURL = legacyStateFileURL
        self.fileManager = fileManager
    }

    public var stateDirectoryURL: URL {
        stateFileURL.deletingLastPathComponent()
    }

    public func load() throws -> PersistedState? {
        if fileManager.fileExists(atPath: stateFileURL.path) {
            let data = try Data(contentsOf: stateFileURL)
            return try JSONDecoder().decode(PersistedState.self, from: data)
        }

        if fileManager.fileExists(atPath: legacyStateFileURL.path) {
            let state = try migrateLegacyState()
            try save(state)
            return state
        }

        return nil
    }

    public func save(_ state: PersistedState) throws {
        try fileManager.createDirectory(at: stateDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(state)
        try data.write(to: stateFileURL, options: .atomic)
    }

    public func clear() throws {
        if fileManager.fileExists(atPath: stateFileURL.path) {
            try fileManager.removeItem(at: stateFileURL)
        }
    }

    private func migrateLegacyState() throws -> PersistedState {
        let contents = try String(contentsOf: legacyStateFileURL, encoding: .utf8)
        var keyValues: [String: String] = [:]

        contents
            .split(separator: "\n", omittingEmptySubsequences: true)
            .forEach { line in
                let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
                guard parts.count == 2 else { return }
                keyValues[parts[0]] = parts[1]
            }

        var originalValues: [String: Int] = [:]
        for key in BuoyPowerKey.allCases {
            if let value = keyValues[key.rawValue], let intValue = Int(value) {
                originalValues[key.rawValue] = intValue
            }
        }

        let config = BuoyConfig(
            displaySleepMinutes: Int(keyValues["display_sleep_minutes"] ?? "") ?? 10,
            clamEnabled: (Int(keyValues["clam_enabled"] ?? "") ?? 0) == 1,
            clamMinBattery: Int(keyValues["clam_min_battery"] ?? "") ?? 25,
            clamPollSeconds: Int(keyValues["clam_poll_seconds"] ?? "") ?? 20
        )

        return PersistedState(
            modeEnabled: true,
            enabledAt: keyValues["enabled_at"],
            config: config,
            clamOriginalSleepDisabled: Int(keyValues["clam_original_sleepdisabled"] ?? ""),
            clamMonitorPID: Int(keyValues["clam_monitor_pid"] ?? ""),
            originalValues: originalValues,
            configuredValues: [:]
        )
    }
}
