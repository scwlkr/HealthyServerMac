import Foundation
import IOKit.ps

public enum PowerMetricsCollector {
    public static func sample() -> PowerSnapshot {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else {
            return PowerSnapshot(
                batteryPercent: nil,
                timeRemainingMinutes: nil,
                powerSource: systemPowerSource(blob: nil),
                condition: nil,
                isCharging: false,
                wattageDraw: nil
            )
        }

        let sourceName = systemPowerSource(blob: blob)

        for src in sources {
            guard let dict = IOPSGetPowerSourceDescription(blob, src)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }

            let capacity = dict[kIOPSCurrentCapacityKey] as? Int
            let max = dict[kIOPSMaxCapacityKey] as? Int
            var percent: Int? = nil
            if let capacity, let max, max > 0 {
                percent = Int(round(Double(capacity) / Double(max) * 100.0))
            }

            let isCharging = (dict[kIOPSIsChargingKey] as? Bool) ?? false
            let timeToEmpty = dict[kIOPSTimeToEmptyKey] as? Int
            let timeToFull = dict[kIOPSTimeToFullChargeKey] as? Int
            var timeRemaining: Int? = nil
            if isCharging, let timeToFull, timeToFull > 0 { timeRemaining = timeToFull }
            else if let timeToEmpty, timeToEmpty > 0 { timeRemaining = timeToEmpty }

            let condition = dict["BatteryHealth"] as? String ?? dict[kIOPSBatteryHealthKey] as? String

            let wattage = readWattage()

            return PowerSnapshot(
                batteryPercent: percent,
                timeRemainingMinutes: timeRemaining,
                powerSource: sourceName,
                condition: condition,
                isCharging: isCharging,
                wattageDraw: wattage
            )
        }

        // No battery entries (desktop Mac).
        return PowerSnapshot(
            batteryPercent: nil,
            timeRemainingMinutes: nil,
            powerSource: sourceName,
            condition: nil,
            isCharging: false,
            wattageDraw: nil
        )
    }

    private static func systemPowerSource(blob: CFTypeRef?) -> String {
        if let blob,
           let type = IOPSGetProvidingPowerSourceType(blob)?.takeUnretainedValue() as String? {
            if type == kIOPMACPowerKey { return "AC Power" }
            if type == kIOPMBatteryPowerKey { return "Battery Power" }
            if type == kIOPMUPSPowerKey { return "UPS Power" }
            return type
        }
        return "Unknown"
    }

    // Approximate instantaneous wattage by reading IOPMPowerSource amperage * voltage.
    private static func readWattage() -> Double? {
        // IOPMCopyBatteryInfo is legacy; use IORegistry AppleSmartBattery keys instead.
        let matching = IOServiceMatching("AppleSmartBattery")
        let service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        func numberValue(_ key: String) -> Double? {
            guard let cf = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() else {
                return nil
            }
            if let n = cf as? NSNumber { return n.doubleValue }
            return nil
        }

        // Amperage is signed (negative = discharging); Voltage is in mV.
        guard let amperage = numberValue("Amperage"),
              let voltage = numberValue("Voltage") else {
            return nil
        }
        // amperage in mA, voltage in mV — watts = (mA/1000) * (mV/1000)
        let watts = (amperage / 1000.0) * (voltage / 1000.0)
        return abs(watts)
    }
}
