import Foundation
import IOKit
import IOKit.ps

public enum ThermalMetricsCollector {
    public static func sample() -> ThermalSnapshot {
        let battery = batteryTempC()
        let cpu = cpuTempC()
        let level = thermalLevelString()
        return ThermalSnapshot(cpuTempCelsius: cpu, batteryTempCelsius: battery, thermalLevel: level)
    }

    // Battery temperature from AppleSmartBattery registry (value in 1/100 °C)
    private static func batteryTempC() -> Double? {
        let matching = IOServiceMatching("AppleSmartBattery")
        let service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        guard let cf = IORegistryEntryCreateCFProperty(service, "Temperature" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue(),
              let n = cf as? NSNumber else {
            return nil
        }
        let raw = n.doubleValue
        // Reported in centi-degrees Celsius.
        return raw / 100.0
    }

    // CPU temperature without entitlements is unreliable on Apple Silicon.
    // We report nil rather than fake data, and surface a thermal pressure level instead.
    private static func cpuTempC() -> Double? {
        return nil
    }

    private static func thermalLevelString() -> String? {
        let state = ProcessInfo.processInfo.thermalState
        switch state {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return nil
        }
    }
}
