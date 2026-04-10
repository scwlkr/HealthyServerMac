import Darwin
import Foundation

public final class CPUMetricsCollector {
    private var previousTicks: [host_cpu_load_info] = []
    private let lock = NSLock()

    public init() {}

    public func sample() -> CPUSnapshot {
        let (overall, perCore) = readLoads()
        let freq = readFrequencyGHz()
        return CPUSnapshot(overallPercent: overall, perCorePercent: perCore, frequencyGHz: freq)
    }

    // MARK: - Per-core load via host_processor_info

    private func readLoads() -> (Double, [Double]) {
        var coreCountU: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var cpuInfoCount: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &coreCountU,
            &cpuInfo,
            &cpuInfoCount
        )
        guard result == KERN_SUCCESS, let cpuInfo else {
            return (0, [])
        }

        defer {
            let size = vm_size_t(Int(cpuInfoCount) * MemoryLayout<integer_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), size)
        }

        let coreCount = Int(coreCountU)
        var current: [host_cpu_load_info] = []
        current.reserveCapacity(coreCount)

        for core in 0..<coreCount {
            let base = core * Int(CPU_STATE_MAX)
            var info = host_cpu_load_info()
            info.cpu_ticks.0 = natural_t(cpuInfo[base + Int(CPU_STATE_USER)])
            info.cpu_ticks.1 = natural_t(cpuInfo[base + Int(CPU_STATE_SYSTEM)])
            info.cpu_ticks.2 = natural_t(cpuInfo[base + Int(CPU_STATE_IDLE)])
            info.cpu_ticks.3 = natural_t(cpuInfo[base + Int(CPU_STATE_NICE)])
            current.append(info)
        }

        lock.lock()
        let previous = previousTicks
        previousTicks = current
        lock.unlock()

        guard previous.count == current.count else {
            return (0, Array(repeating: 0, count: coreCount))
        }

        var perCore: [Double] = []
        perCore.reserveCapacity(coreCount)
        var totalUsed: Double = 0
        var totalAll: Double = 0

        for i in 0..<coreCount {
            let user = Double(current[i].cpu_ticks.0 &- previous[i].cpu_ticks.0)
            let system = Double(current[i].cpu_ticks.1 &- previous[i].cpu_ticks.1)
            let idle = Double(current[i].cpu_ticks.2 &- previous[i].cpu_ticks.2)
            let nice = Double(current[i].cpu_ticks.3 &- previous[i].cpu_ticks.3)
            let used = user + system + nice
            let total = used + idle
            let percent = total > 0 ? (used / total) * 100.0 : 0
            perCore.append(percent)
            totalUsed += used
            totalAll += total
        }

        let overall = totalAll > 0 ? (totalUsed / totalAll) * 100.0 : 0
        return (overall, perCore)
    }

    // MARK: - Frequency

    private func readFrequencyGHz() -> Double? {
        // Intel: hw.cpufrequency is nominal Hz.
        if let hz = sysctlUInt64("hw.cpufrequency"), hz > 0 {
            return Double(hz) / 1_000_000_000.0
        }
        // Apple Silicon: parse brand string for nominal.
        if let brand = sysctlString("machdep.cpu.brand_string") {
            if let ghz = Self.extractGHz(from: brand) {
                return ghz
            }
        }
        // Last resort: tbfrequency is timebase not cpu; skip.
        return nil
    }

    private static func extractGHz(from brand: String) -> Double? {
        // e.g. "Apple M2 Pro" — no frequency. "Intel(R) Core(TM) i7-9750H CPU @ 2.60GHz"
        let pattern = try? NSRegularExpression(pattern: "([0-9]+\\.[0-9]+)\\s*GHz", options: .caseInsensitive)
        guard let match = pattern?.firstMatch(in: brand, range: NSRange(brand.startIndex..., in: brand)),
              match.numberOfRanges >= 2,
              let range = Range(match.range(at: 1), in: brand) else {
            return nil
        }
        return Double(brand[range])
    }

    private func sysctlUInt64(_ name: String) -> UInt64? {
        var size = MemoryLayout<UInt64>.size
        var value: UInt64 = 0
        let ret = sysctlbyname(name, &value, &size, nil, 0)
        return ret == 0 ? value : nil
    }

    private func sysctlString(_ name: String) -> String? {
        var size = 0
        if sysctlbyname(name, nil, &size, nil, 0) != 0 { return nil }
        var buf = [CChar](repeating: 0, count: size)
        if sysctlbyname(name, &buf, &size, nil, 0) != 0 { return nil }
        return String(cString: buf)
    }
}
