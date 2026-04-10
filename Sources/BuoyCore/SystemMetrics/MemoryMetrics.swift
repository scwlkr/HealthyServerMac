import Darwin
import Foundation

public enum MemoryMetricsCollector {
    public static func sample() -> MemorySnapshot {
        var totalBytes: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &totalBytes, &size, nil, 0)

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, reboundPtr, &count)
            }
        }

        let pageSizeValue: UInt64 = UInt64(vm_kernel_page_size)

        guard result == KERN_SUCCESS, totalBytes > 0 else {
            return .empty
        }

        let free = UInt64(stats.free_count) * pageSizeValue
        let active = UInt64(stats.active_count) * pageSizeValue
        let inactive = UInt64(stats.inactive_count) * pageSizeValue
        let wired = UInt64(stats.wire_count) * pageSizeValue
        let compressed = UInt64(stats.compressor_page_count) * pageSizeValue

        // macOS "used" roughly = app + wired + compressed = active + wired + compressed
        let used = active + wired + compressed
        let available = free + inactive
        let totalGB = Double(totalBytes) / 1_073_741_824.0
        let usedGB = Double(used) / 1_073_741_824.0
        let availGB = Double(available) / 1_073_741_824.0
        let percent = totalBytes > 0 ? (Double(used) / Double(totalBytes)) * 100.0 : 0

        return MemorySnapshot(
            totalGB: totalGB,
            usedGB: usedGB,
            availableGB: availGB,
            usagePercent: percent
        )
    }

    public static var totalBytes: UInt64 {
        var totalBytes: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &totalBytes, &size, nil, 0)
        return totalBytes
    }
}
