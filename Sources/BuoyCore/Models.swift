import Foundation

public let buoyVersion = "1.0.0"
public let buoyProductName = "Buoy"
public let buoyCommandName = "buoy"
public let buoyLegacyCommandName = "healthyservermac"

public enum BuoyPowerKey: String, CaseIterable, Codable {
    case sleep
    case displaysleep
    case standby
    case powernap
    case womp
    case ttyskeepawake
    case tcpkeepalive
}

public struct BuoyConfig: Codable, Equatable {
    public var displaySleepMinutes: Int
    public var clamEnabled: Bool
    public var clamMinBattery: Int
    public var clamPollSeconds: Int

    public init(
        displaySleepMinutes: Int = 10,
        clamEnabled: Bool = false,
        clamMinBattery: Int = 25,
        clamPollSeconds: Int = 20
    ) {
        self.displaySleepMinutes = displaySleepMinutes
        self.clamEnabled = clamEnabled
        self.clamMinBattery = clamMinBattery
        self.clamPollSeconds = clamPollSeconds
    }
}

public struct PersistedState: Codable, Equatable {
    public var schemaVersion: Int
    public var modeEnabled: Bool
    public var enabledAt: String?
    public var config: BuoyConfig?
    public var clamOriginalSleepDisabled: Int?
    public var clamMonitorPID: Int?
    public var originalValues: [String: Int]
    public var configuredValues: [String: Int]

    public init(
        schemaVersion: Int = 1,
        modeEnabled: Bool = false,
        enabledAt: String? = nil,
        config: BuoyConfig? = nil,
        clamOriginalSleepDisabled: Int? = nil,
        clamMonitorPID: Int? = nil,
        originalValues: [String: Int] = [:],
        configuredValues: [String: Int] = [:]
    ) {
        self.schemaVersion = schemaVersion
        self.modeEnabled = modeEnabled
        self.enabledAt = enabledAt
        self.config = config
        self.clamOriginalSleepDisabled = clamOriginalSleepDisabled
        self.clamMonitorPID = clamMonitorPID
        self.originalValues = originalValues
        self.configuredValues = configuredValues
    }
}

public struct BuoyProductInfo: Codable, Equatable {
    public var name: String
    public var version: String
    public var command: String
    public var legacyAlias: String

    enum CodingKeys: String, CodingKey {
        case name
        case version
        case command
        case legacyAlias = "legacy_alias"
    }
}

public struct BuoyModeStatus: Codable, Equatable {
    public var enabled: Bool
    public var enabledAt: String?
    public var displaySleepMinutes: Int?
}

public struct BuoyClamStatus: Codable, Equatable {
    public var enabled: Bool
    public var minBattery: Int?
    public var pollSeconds: Int?
    public var monitorPID: Int?
    public var monitorRunning: Bool
}

public struct BuoySystemStatus: Codable, Equatable {
    public var powerSource: String
    public var batteryPercent: Int?
    public var sleepDisabled: Int?
}

public struct BuoyPathStatus: Codable, Equatable {
    public var stateFile: String

    enum CodingKeys: String, CodingKey {
        case stateFile = "state_file"
    }
}

public struct BuoyStatus: Codable, Equatable {
    public var product: BuoyProductInfo
    public var mode: BuoyModeStatus
    public var clam: BuoyClamStatus
    public var system: BuoySystemStatus
    public var paths: BuoyPathStatus
    public var managedAC: [String: Int]
    public var configured: [String: Int]
    public var original: [String: Int]

    enum CodingKeys: String, CodingKey {
        case product
        case mode
        case clam
        case system
        case paths
        case managedAC = "managed_ac"
        case configured
        case original
    }
}

public struct DoctorStatus: Codable, Equatable {
    public var macOS: Bool
    public var pmset: Bool
    public var osascript: Bool
    public var swift: Bool
    public var xcodebuild: Bool
    public var stateDir: String
    public var stateFile: String
}

public struct CommandOutput: Equatable {
    public var stdout: String
    public var stderr: String
    public var exitCode: Int32
}

public enum BuoyError: LocalizedError {
    case invalidArgument(String)
    case commandFailed(String)
    case missingExecutable(String)
    case io(String)

    public var errorDescription: String? {
        switch self {
        case .invalidArgument(let message):
            return message
        case .commandFailed(let message):
            return message
        case .missingExecutable(let message):
            return message
        case .io(let message):
            return message
        }
    }
}

public enum BuoyPaths {
    public static let defaultStateDirectoryName = ".buoy"
    public static let legacyStateDirectoryName = ".healthyservermac"
    public static let stateFileName = "state.json"
    public static let legacyStateFileName = "ac-settings.state"

    public static func defaultStateDirectory(environment: [String: String] = ProcessInfo.processInfo.environment) -> URL {
        let homeDirectory = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)

        if let explicit = environment["BUOY_STATE_DIR"], !explicit.isEmpty {
            return URL(fileURLWithPath: explicit, isDirectory: true)
        }
        if let explicit = environment["HEALTHYSERVERMAC_STATE_DIR"], !explicit.isEmpty {
            return URL(fileURLWithPath: explicit, isDirectory: true)
        }

        return homeDirectory.appendingPathComponent(defaultStateDirectoryName, isDirectory: true)
    }

    public static func stateFileURL(environment: [String: String] = ProcessInfo.processInfo.environment) -> URL {
        defaultStateDirectory(environment: environment).appendingPathComponent(stateFileName)
    }

    public static func legacyStateFileURL(environment: [String: String] = ProcessInfo.processInfo.environment) -> URL {
        if let explicit = environment["HEALTHYSERVERMAC_STATE_DIR"], !explicit.isEmpty {
            return URL(fileURLWithPath: explicit, isDirectory: true).appendingPathComponent(legacyStateFileName)
        }
        let homeDirectory = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        return homeDirectory
            .appendingPathComponent(legacyStateDirectoryName, isDirectory: true)
            .appendingPathComponent(legacyStateFileName)
    }
}
