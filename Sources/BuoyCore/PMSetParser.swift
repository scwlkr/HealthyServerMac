import Foundation

public enum PMSetParser {
    public static func parseCapabilities(_ output: String, section: String = "Capabilities for AC Power:") -> Set<BuoyPowerKey> {
        var capture = false
        var keys = Set<BuoyPowerKey>()

        for line in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed == section {
                capture = true
                continue
            }
            if capture && trimmed.hasPrefix("Capabilities for ") {
                break
            }
            if capture, let token = trimmed.split(separator: " ").first, let key = BuoyPowerKey(rawValue: String(token)) {
                keys.insert(key)
            }
        }

        return keys
    }

    public static func parseCustomSettings(_ output: String, section: String = "AC Power:") -> [BuoyPowerKey: Int] {
        var capture = false
        var values: [BuoyPowerKey: Int] = [:]

        for line in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let raw = String(line)
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed == section {
                capture = true
                continue
            }

            if capture && trimmed.hasSuffix("Power:") && trimmed != section {
                break
            }

            guard capture else { continue }

            let components = trimmed.split(whereSeparator: \.isWhitespace)
            guard let keyPart = components.first, let valuePart = components.last else { continue }
            guard let key = BuoyPowerKey(rawValue: String(keyPart)), let value = Int(valuePart) else { continue }
            values[key] = value
        }

        return values
    }

    public static func currentPowerSource(_ output: String) -> String {
        for line in output.split(separator: "\n") {
            if let start = line.firstIndex(of: "'"), let end = line[line.index(after: start)...].firstIndex(of: "'") {
                return String(line[line.index(after: start)..<end])
            }
        }
        return "Unknown"
    }

    public static func currentBatteryPercentage(_ output: String) -> Int? {
        let pattern = #"[0-9]+%"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(output.startIndex..<output.endIndex, in: output)
        guard let match = regex.firstMatch(in: output, range: range),
              let matchRange = Range(match.range, in: output) else {
            return nil
        }
        return Int(output[matchRange].replacingOccurrences(of: "%", with: ""))
    }

    public static func currentSleepDisabled(_ output: String) -> Int? {
        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("SleepDisabled") else { continue }
            let components = trimmed.split(whereSeparator: \.isWhitespace)
            guard let last = components.last else { continue }
            return Int(last)
        }
        return nil
    }

    public static func desiredValues(
        supported: Set<BuoyPowerKey>,
        config: BuoyConfig
    ) -> [BuoyPowerKey: Int] {
        var values: [BuoyPowerKey: Int] = [:]

        for key in BuoyPowerKey.allCases where supported.contains(key) {
            switch key {
            case .sleep:
                values[key] = 0
            case .displaysleep:
                values[key] = config.displaySleepMinutes
            case .standby:
                values[key] = 0
            case .powernap:
                values[key] = 0
            case .womp:
                values[key] = 1
            case .ttyskeepawake:
                values[key] = 1
            case .tcpkeepalive:
                values[key] = 1
            }
        }

        return values
    }
}
