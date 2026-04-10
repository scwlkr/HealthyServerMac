import Foundation

// MARK: - Dashboard Snapshot

public struct DashboardSnapshot {
    public var capturedAt: Date
    public var cpu: CPUSnapshot
    public var memory: MemorySnapshot
    public var disk: DiskSnapshot
    public var power: PowerSnapshot
    public var thermal: ThermalSnapshot
    public var processes: [ProcessInfoRow]
    public var services: [ServiceInfoRow]
    public var network: NetworkSnapshot

    public init(
        capturedAt: Date = Date(),
        cpu: CPUSnapshot = .empty,
        memory: MemorySnapshot = .empty,
        disk: DiskSnapshot = .empty,
        power: PowerSnapshot = .empty,
        thermal: ThermalSnapshot = .empty,
        processes: [ProcessInfoRow] = [],
        services: [ServiceInfoRow] = [],
        network: NetworkSnapshot = .empty
    ) {
        self.capturedAt = capturedAt
        self.cpu = cpu
        self.memory = memory
        self.disk = disk
        self.power = power
        self.thermal = thermal
        self.processes = processes
        self.services = services
        self.network = network
    }
}

// MARK: - CPU

public struct CPUSnapshot {
    public var overallPercent: Double
    public var perCorePercent: [Double]
    public var frequencyGHz: Double?

    public static let empty = CPUSnapshot(overallPercent: 0, perCorePercent: [], frequencyGHz: nil)
}

// MARK: - Memory

public struct MemorySnapshot {
    public var totalGB: Double
    public var usedGB: Double
    public var availableGB: Double
    public var usagePercent: Double

    public static let empty = MemorySnapshot(totalGB: 0, usedGB: 0, availableGB: 0, usagePercent: 0)
}

// MARK: - Disk

public struct DiskSnapshot {
    public var totalGB: Double
    public var usedGB: Double
    public var availableGB: Double
    public var usagePercent: Double
    public var mountPoint: String

    public static let empty = DiskSnapshot(totalGB: 0, usedGB: 0, availableGB: 0, usagePercent: 0, mountPoint: "/")
}

// MARK: - Power

public struct PowerSnapshot {
    public var batteryPercent: Int?
    public var timeRemainingMinutes: Int?
    public var powerSource: String
    public var condition: String?
    public var isCharging: Bool
    public var wattageDraw: Double?

    public static let empty = PowerSnapshot(
        batteryPercent: nil,
        timeRemainingMinutes: nil,
        powerSource: "Unknown",
        condition: nil,
        isCharging: false,
        wattageDraw: nil
    )
}

// MARK: - Thermal

public struct ThermalSnapshot {
    public var cpuTempCelsius: Double?
    public var batteryTempCelsius: Double?
    public var thermalLevel: String?

    public static let empty = ThermalSnapshot(cpuTempCelsius: nil, batteryTempCelsius: nil, thermalLevel: nil)
}

// MARK: - Process

public struct ProcessInfoRow: Identifiable, Equatable {
    public var id: Int32 { pid }
    public var pid: Int32
    public var ppid: Int32
    public var name: String
    public var cpuPercent: Double
    public var memoryMB: Double
    public var memoryPercent: Double
    public var state: String
    public var user: String

    public init(
        pid: Int32,
        ppid: Int32,
        name: String,
        cpuPercent: Double,
        memoryMB: Double,
        memoryPercent: Double,
        state: String,
        user: String
    ) {
        self.pid = pid
        self.ppid = ppid
        self.name = name
        self.cpuPercent = cpuPercent
        self.memoryMB = memoryMB
        self.memoryPercent = memoryPercent
        self.state = state
        self.user = user
    }
}

public enum ProcessSortKey: String, CaseIterable {
    case cpu = "CPU"
    case memory = "Memory"
    case pid = "PID"
    case name = "Name"
    case user = "User"
}

// MARK: - Services

public enum ServiceStatus: String {
    case running = "Running"
    case stopped = "Stopped"
    case disabled = "Disabled"
    case unknown = "Unknown"
}

public enum ServiceLocation: String, CaseIterable {
    case systemDaemons = "/System/Library/LaunchDaemons"
    case systemAgents = "/System/Library/LaunchAgents"
    case libraryDaemons = "/Library/LaunchDaemons"
    case libraryAgents = "/Library/LaunchAgents"
    case userAgents = "~/Library/LaunchAgents"

    public var resolvedPath: String {
        if self == .userAgents {
            return (NSHomeDirectory() as NSString).appendingPathComponent("Library/LaunchAgents")
        }
        return self.rawValue
    }
}

public enum ServiceGroup: String {
    case systemDaemon = "System Daemons"
    case userAgent = "User Agents"
    case thirdParty = "Third-Party"
}

public struct ServiceInfoRow: Equatable {
    public var label: String
    public var plistPath: String
    public var location: ServiceLocation
    public var group: ServiceGroup
    public var status: ServiceStatus
    public var enabledOnBoot: Bool
    public var pid: Int32?
    public var cpuPercent: Double?
    public var memoryMB: Double?
}

// MARK: - Network

public struct NetworkSnapshot {
    public var listeningPorts: [ListeningPort]
    public var interfaces: [NetworkInterfaceInfo]

    public static let empty = NetworkSnapshot(listeningPorts: [], interfaces: [])
}

public struct ListeningPort: Equatable {
    public var service: String
    public var proto: String
    public var port: Int
    public var localAddress: String
    public var owner: String
    public var pid: Int32?
}

public struct NetworkInterfaceInfo: Equatable {
    public var name: String
    public var ipv4: [String]
    public var ipv6: [String]
    public var mac: String?
    public var isUp: Bool
}
