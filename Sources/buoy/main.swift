import Foundation

struct CLI {
    static func main() {
        do {
            try run()
        } catch {
            fputs("Error: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }

    private static func run() throws {
        let args = Array(CommandLine.arguments.dropFirst())
        let command = args.first ?? "help"
        let rest = Array(args.dropFirst())
        let engine = BuoyEngine()

        switch command {
        case "apply", "on", "enable":
            let options = try parseApplyOptions(rest)
            try printLines(engine.apply(config: options.config, dryRun: options.dryRun))
        case "off", "disable":
            let dryRun = try parseFlag(rest, allowed: ["--dry-run"])
            try printLines(engine.disable(dryRun: dryRun))
        case "status":
            let json = try parseFlag(rest, allowed: ["--json"])
            if json {
                try printJSON(engine.status())
            } else {
                try printHumanStatus(engine.status())
            }
        case "doctor":
            let json = try parseFlag(rest, allowed: ["--json"])
            if json {
                try printJSON(engine.doctor())
            } else {
                try printHumanDoctor(engine.doctor())
            }
        case "screen-off":
            let dryRun = try parseFlag(rest, allowed: ["--dry-run"])
            try printLines(engine.screenOff(dryRun: dryRun))
        case "install":
            let install = try parseInstallOptions(rest)
            try printLines(engine.install(targetDirectory: install.targetDirectory, dryRun: install.dryRun))
        case "path-add":
            let dryRun = try parseFlag(rest, allowed: ["--dry-run"])
            try printLines(engine.appendProjectToPATH(dryRun: dryRun))
        case "__clam-monitor":
            guard rest.count == 3, let minBattery = Int(rest[1]), let pollSeconds = Int(rest[2]) else {
                throw BuoyError.invalidArgument("Internal error: __clam-monitor expects STATE_FILE MIN_BATTERY POLL_SECONDS.")
            }
            try engine.runClamMonitor(stateFilePath: rest[0], minBattery: minBattery, pollSeconds: pollSeconds)
        case "help", "-h", "--help":
            printUsage()
        case "version", "--version":
            print(buoyVersion)
        default:
            throw BuoyError.invalidArgument("Unknown command: \(command)")
        }
    }

    private static func parseApplyOptions(_ arguments: [String]) throws -> (config: BuoyConfig, dryRun: Bool) {
        var config = BuoyConfig(
            displaySleepMinutes: Int(ProcessInfo.processInfo.environment["BUOY_DISPLAY_SLEEP"] ?? "10") ?? 10,
            clamEnabled: false,
            clamMinBattery: Int(ProcessInfo.processInfo.environment["BUOY_CLAM_MIN_BATTERY"] ?? "25") ?? 25,
            clamPollSeconds: Int(ProcessInfo.processInfo.environment["BUOY_CLAM_POLL_SECONDS"] ?? "20") ?? 20
        )
        var dryRun = false
        var index = 0

        while index < arguments.count {
            switch arguments[index] {
            case "--display-sleep":
                index += 1
                guard index < arguments.count, let value = Int(arguments[index]) else {
                    throw BuoyError.invalidArgument("Missing integer value after --display-sleep.")
                }
                config.displaySleepMinutes = value
            case "--clam", "-clam", "--closed-lid":
                config.clamEnabled = true
            case "--clam-min-battery":
                index += 1
                guard index < arguments.count, let value = Int(arguments[index]) else {
                    throw BuoyError.invalidArgument("Missing integer value after --clam-min-battery.")
                }
                config.clamMinBattery = value
            case "--clam-poll-seconds":
                index += 1
                guard index < arguments.count, let value = Int(arguments[index]) else {
                    throw BuoyError.invalidArgument("Missing integer value after --clam-poll-seconds.")
                }
                config.clamPollSeconds = value
            case "--dry-run":
                dryRun = true
            default:
                throw BuoyError.invalidArgument("Unknown argument for apply: \(arguments[index])")
            }
            index += 1
        }

        return (config, dryRun)
    }

    private static func parseInstallOptions(_ arguments: [String]) throws -> (targetDirectory: URL, dryRun: Bool) {
        var dryRun = false
        var targetDirectory = URL(fileURLWithPath: "/usr/local/bin", isDirectory: true)
        if !FileManager.default.isWritableFile(atPath: targetDirectory.path) {
            targetDirectory = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
                .appendingPathComponent(".local", isDirectory: true)
                .appendingPathComponent("bin", isDirectory: true)
        }

        var index = 0
        while index < arguments.count {
            switch arguments[index] {
            case "--target-dir":
                index += 1
                guard index < arguments.count else {
                    throw BuoyError.invalidArgument("Missing value after --target-dir.")
                }
                targetDirectory = URL(fileURLWithPath: arguments[index], isDirectory: true)
            case "--dry-run":
                dryRun = true
            default:
                throw BuoyError.invalidArgument("Unknown argument for install: \(arguments[index])")
            }
            index += 1
        }

        return (targetDirectory, dryRun)
    }

    private static func parseFlag(_ arguments: [String], allowed: Set<String>) throws -> Bool {
        var enabled = false
        for argument in arguments {
            guard allowed.contains(argument) else {
                throw BuoyError.invalidArgument("Unknown argument: \(argument)")
            }
            enabled = true
        }
        return enabled
    }

    private static func printLines(_ lines: [String]) throws {
        lines.forEach { print($0) }
    }

    private static func printJSON<T: Encodable>(_ value: T) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(value)
        if let string = String(data: data, encoding: .utf8) {
            print(string)
        }
    }

    private static func printHumanStatus(_ status: BuoyStatus) throws {
        print("Mode: \(status.mode.enabled ? "enabled" : "disabled")")
        if let enabledAt = status.mode.enabledAt {
            print("Enabled at: \(enabledAt)")
        }
        if let displaySleep = status.mode.displaySleepMinutes {
            print("Configured display sleep: \(displaySleep) minute(s)")
        }
        print("Closed-lid awake mode: \(status.clam.enabled ? "enabled" : "disabled")")
        if let minBattery = status.clam.minBattery {
            print("Closed-lid battery threshold: > \(minBattery)%")
        }
        if let pollSeconds = status.clam.pollSeconds {
            print("Closed-lid poll interval: \(pollSeconds)s")
        }
        if let pid = status.clam.monitorPID {
            print("Closed-lid monitor: \(status.clam.monitorRunning ? "running (pid \(pid))" : "not running")")
        }
        print("State file: \(status.paths.stateFile)")
        print("Power source: \(status.system.powerSource)")
        if let battery = status.system.batteryPercent {
            print("Battery level: \(battery)%")
        }
        if let sleepDisabled = status.system.sleepDisabled {
            print("SleepDisabled: \(sleepDisabled)")
        }
        print("Current managed AC settings:")
        for key in BuoyPowerKey.allCases {
            if let value = status.managedAC[key.rawValue] {
                let label = "\(key.rawValue):"
                let padding = String(repeating: " ", count: max(1, 14 - label.count))
                print("  \(label)\(padding)\(value)")
            }
        }
    }

    private static func printHumanDoctor(_ doctor: DoctorStatus) throws {
        print("macOS: \(doctor.macOS ? "ok" : "missing")")
        print("pmset: \(doctor.pmset ? "ok" : "missing")")
        print("osascript: \(doctor.osascript ? "ok" : "missing")")
        print("swift: \(doctor.swift ? "ok" : "missing")")
        print("xcodebuild: \(doctor.xcodebuild ? "ok" : "missing")")
        print("State dir: \(doctor.stateDir)")
        print("State file: \(doctor.stateFile)")
    }

    private static func printUsage() {
        print(
            """
            Usage:
              buoy apply [--display-sleep MINUTES] [--clam] [--clam-min-battery PERCENT] [--clam-poll-seconds SECONDS] [--dry-run]
              buoy on [--display-sleep MINUTES] [--clam] [--clam-min-battery PERCENT] [--clam-poll-seconds SECONDS] [--dry-run]
              buoy off [--dry-run]
              buoy status [--json]
              buoy doctor [--json]
              buoy screen-off [--dry-run]
              buoy install [--target-dir DIR] [--dry-run]
              buoy path-add [--dry-run]
              buoy help
            """
        )
    }
}

CLI.main()
