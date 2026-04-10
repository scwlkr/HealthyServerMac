import Foundation

public final class ServiceMetricsCollector {
    private let processCollector: ProcessMetricsCollector

    public init(processCollector: ProcessMetricsCollector = ProcessMetricsCollector()) {
        self.processCollector = processCollector
    }

    public func sample(with processes: [ProcessInfoRow]) -> [ServiceInfoRow] {
        let launchctlMap = Self.readLaunchctlList()
        var rows: [ServiceInfoRow] = []
        let fm = FileManager.default

        for location in ServiceLocation.allCases {
            let path = location.resolvedPath
            guard let contents = try? fm.contentsOfDirectory(atPath: path) else { continue }
            for entry in contents where entry.hasSuffix(".plist") {
                let plistPath = (path as NSString).appendingPathComponent(entry)
                guard let data = try? Data(contentsOf: URL(fileURLWithPath: plistPath)),
                      let raw = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
                      let dict = raw as? [String: Any] else {
                    continue
                }
                let label = (dict["Label"] as? String) ?? (entry as NSString).deletingPathExtension
                let disabled = (dict["Disabled"] as? Bool) ?? false
                let runAtLoad = (dict["RunAtLoad"] as? Bool) ?? false
                let keepAlive = (dict["KeepAlive"] as? Bool) ?? false

                let entry = launchctlMap[label]
                let pid = entry?.pid
                var status: ServiceStatus = .unknown
                if disabled {
                    status = .disabled
                } else if let pid, pid > 0 {
                    status = .running
                } else if entry != nil {
                    status = .stopped
                } else {
                    status = .stopped
                }

                let enabledOnBoot = runAtLoad || keepAlive

                var cpu: Double? = nil
                var mem: Double? = nil
                if let pid = pid, pid > 0 {
                    if let proc = processes.first(where: { $0.pid == pid }) {
                        cpu = proc.cpuPercent
                        mem = proc.memoryMB
                    }
                }

                let group = Self.classify(location: location, label: label)

                rows.append(ServiceInfoRow(
                    label: label,
                    plistPath: plistPath,
                    location: location,
                    group: group,
                    status: status,
                    enabledOnBoot: enabledOnBoot,
                    pid: pid,
                    cpuPercent: cpu,
                    memoryMB: mem
                ))
            }
        }

        rows.sort { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
        return rows
    }

    private static func classify(location: ServiceLocation, label: String) -> ServiceGroup {
        switch location {
        case .systemDaemons, .systemAgents:
            return .systemDaemon
        case .userAgents:
            return .userAgent
        case .libraryDaemons, .libraryAgents:
            if label.hasPrefix("com.apple.") { return .systemDaemon }
            return .thirdParty
        }
    }

    // Parse `launchctl list` once per sample. Format:
    // PID\tStatus\tLabel
    private static func readLaunchctlList() -> [String: (pid: Int32?, status: Int32)] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        task.arguments = ["list"]
        let outPipe = Pipe()
        let errPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = errPipe

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return [:]
        }

        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8) else { return [:] }

        var map: [String: (pid: Int32?, status: Int32)] = [:]
        let lines = text.split(separator: "\n")
        for (idx, line) in lines.enumerated() where idx > 0 {
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard parts.count >= 3 else { continue }
            let pidStr = parts[0].trimmingCharacters(in: .whitespaces)
            let statusStr = parts[1].trimmingCharacters(in: .whitespaces)
            let label = parts[2].trimmingCharacters(in: .whitespaces)

            let pid: Int32? = (pidStr == "-") ? nil : Int32(pidStr)
            let status = Int32(statusStr) ?? 0
            map[label] = (pid, status)
        }
        return map
    }
}
