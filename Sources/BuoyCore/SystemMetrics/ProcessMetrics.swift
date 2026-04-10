import Darwin
import Foundation

public final class ProcessMetricsCollector {
    // Previous sample of total CPU time per PID for delta-based CPU%.
    private var previousCPUTime: [Int32: UInt64] = [:]
    private var previousTimestamp: Date?
    private let lock = NSLock()
    private let numCPUs: Double

    public init() {
        var count: Int32 = 0
        var size = MemoryLayout<Int32>.size
        sysctlbyname("hw.ncpu", &count, &size, nil, 0)
        self.numCPUs = Double(max(1, count))
    }

    public func sample() -> [ProcessInfoRow] {
        guard let kprocs = loadKinfoProcs() else { return [] }
        let now = Date()

        lock.lock()
        let prevTimestamp = previousTimestamp
        let prevCPU = previousCPUTime
        previousTimestamp = now
        lock.unlock()

        let elapsed = prevTimestamp.map { now.timeIntervalSince($0) } ?? 1.0
        let totalMem = Double(MemoryMetricsCollector.totalBytes)

        var rows: [ProcessInfoRow] = []
        rows.reserveCapacity(kprocs.count)
        var currentCPU: [Int32: UInt64] = [:]
        currentCPU.reserveCapacity(kprocs.count)

        for kp in kprocs {
            let pid = kp.kp_proc.p_pid
            guard pid > 0 else { continue }

            let name = withUnsafePointer(to: kp.kp_proc.p_comm) { ptr -> String in
                ptr.withMemoryRebound(to: CChar.self, capacity: Int(MAXCOMLEN) + 1) {
                    String(cString: $0)
                }
            }

            let ppid = kp.kp_eproc.e_ppid
            let uid = kp.kp_eproc.e_pcred.p_ruid
            let user = Self.resolveUsername(uid: uid)
            let state = Self.decodeState(kp.kp_proc.p_stat)

            // Fetch task info via proc_pidinfo
            var taskInfo = proc_taskinfo()
            let size = MemoryLayout<proc_taskinfo>.size
            let ret = withUnsafeMutablePointer(to: &taskInfo) { ptr -> Int32 in
                ptr.withMemoryRebound(to: Int8.self, capacity: size) { rebound in
                    proc_pidinfo(pid, PROC_PIDTASKINFO, 0, rebound, Int32(size))
                }
            }

            var cpuPercent: Double = 0
            var memMB: Double = 0
            var memPct: Double = 0

            if ret == Int32(size) {
                let totalNs = taskInfo.pti_total_user &+ taskInfo.pti_total_system
                currentCPU[pid] = totalNs
                if let prior = prevCPU[pid], elapsed > 0 {
                    let deltaNs = Double(totalNs &- prior)
                    let elapsedNs = elapsed * 1_000_000_000.0
                    // Normalize against a single core (top-style): percent can exceed 100 for multi-threaded.
                    cpuPercent = (deltaNs / elapsedNs) * 100.0
                    if cpuPercent < 0 { cpuPercent = 0 }
                }
                let rss = Double(taskInfo.pti_resident_size)
                memMB = rss / 1_048_576.0
                memPct = totalMem > 0 ? (rss / totalMem) * 100.0 : 0
            }

            rows.append(ProcessInfoRow(
                pid: pid,
                ppid: ppid,
                name: name.isEmpty ? "(unknown)" : name,
                cpuPercent: cpuPercent,
                memoryMB: memMB,
                memoryPercent: memPct,
                state: state,
                user: user
            ))
        }

        lock.lock()
        previousCPUTime = currentCPU
        lock.unlock()

        return rows
    }

    // MARK: - kinfo_proc loading

    private func loadKinfoProcs() -> [kinfo_proc]? {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
        var size = 0
        if sysctl(&mib, 4, nil, &size, nil, 0) != 0 { return nil }

        // Retry loop — process set can change between size probe and fetch.
        for _ in 0..<4 {
            let count = size / MemoryLayout<kinfo_proc>.stride
            var buffer = [kinfo_proc](repeating: kinfo_proc(), count: count + 16)
            size = buffer.count * MemoryLayout<kinfo_proc>.stride
            let ret = buffer.withUnsafeMutableBufferPointer { ptr -> Int32 in
                sysctl(&mib, 4, ptr.baseAddress, &size, nil, 0)
            }
            if ret == 0 {
                let actual = size / MemoryLayout<kinfo_proc>.stride
                return Array(buffer.prefix(actual))
            }
            if errno != ENOMEM { return nil }
            size *= 2
        }
        return nil
    }

    // MARK: - Helpers

    private static var usernameCache: [UInt32: String] = [:]
    private static let usernameCacheLock = NSLock()

    private static func resolveUsername(uid: UInt32) -> String {
        usernameCacheLock.lock()
        if let cached = usernameCache[uid] {
            usernameCacheLock.unlock()
            return cached
        }
        usernameCacheLock.unlock()

        guard let pw = getpwuid(uid) else {
            return String(uid)
        }
        let name = String(cString: pw.pointee.pw_name)

        usernameCacheLock.lock()
        usernameCache[uid] = name
        usernameCacheLock.unlock()
        return name
    }

    private static func decodeState(_ stat: Int8) -> String {
        switch Int32(stat) {
        case SIDL: return "idle"
        case SRUN: return "running"
        case SSLEEP: return "sleeping"
        case SSTOP: return "stopped"
        case SZOMB: return "zombie"
        default: return "?"
        }
    }
}
