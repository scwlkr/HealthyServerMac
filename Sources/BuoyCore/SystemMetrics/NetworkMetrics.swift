import Darwin
import Foundation

public enum NetworkMetricsCollector {
    public static func sample() -> NetworkSnapshot {
        let interfaces = collectInterfaces()
        let ports = collectListeningPorts()
        return NetworkSnapshot(listeningPorts: ports, interfaces: interfaces)
    }

    // MARK: - Interfaces via getifaddrs

    private static func collectInterfaces() -> [NetworkInterfaceInfo] {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return [] }
        defer { freeifaddrs(head) }

        var byName: [String: NetworkInterfaceInfo] = [:]
        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let current = ptr {
            let ifa = current.pointee
            let name = String(cString: ifa.ifa_name)
            var info = byName[name] ?? NetworkInterfaceInfo(name: name, ipv4: [], ipv6: [], mac: nil, isUp: false)

            let flags = Int32(ifa.ifa_flags)
            info.isUp = info.isUp || ((flags & IFF_UP) != 0 && (flags & IFF_RUNNING) != 0)

            if let addr = ifa.ifa_addr {
                let family = addr.pointee.sa_family
                if family == UInt8(AF_INET) || family == UInt8(AF_INET6) {
                    var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    let sockLen = socklen_t(family == UInt8(AF_INET) ? MemoryLayout<sockaddr_in>.size : MemoryLayout<sockaddr_in6>.size)
                    if getnameinfo(addr, sockLen, &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
                        let s = String(cString: host)
                        if family == UInt8(AF_INET) {
                            info.ipv4.append(s)
                        } else {
                            info.ipv6.append(s)
                        }
                    }
                } else if family == UInt8(AF_LINK) {
                    info.mac = macString(from: addr)
                }
            }
            byName[name] = info
            ptr = ifa.ifa_next
        }

        return byName.values.sorted { $0.name < $1.name }
    }

    private static func macString(from addr: UnsafePointer<sockaddr>) -> String? {
        return addr.withMemoryRebound(to: sockaddr_dl.self, capacity: 1) { dlPtr -> String? in
            let dl = dlPtr.pointee
            let alen = Int(dl.sdl_alen)
            guard alen == 6 else { return nil }
            let nlen = Int(dl.sdl_nlen)
            var bytes = [UInt8](repeating: 0, count: alen)
            withUnsafePointer(to: dl.sdl_data) { dataPtr in
                dataPtr.withMemoryRebound(to: UInt8.self, capacity: nlen + alen) { rebound in
                    for i in 0..<alen {
                        bytes[i] = rebound[nlen + i]
                    }
                }
            }
            return bytes.map { String(format: "%02x", $0) }.joined(separator: ":")
        }
    }

    // MARK: - Listening ports via lsof

    private static func collectListeningPorts() -> [ListeningPort] {
        // -F pcPnL: parse-friendly, fields: p=pid, c=command, P=protocol, n=name, L=login
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        task.arguments = ["-nP", "-iTCP", "-sTCP:LISTEN", "-iUDP", "-FpcPnL"]
        let out = Pipe()
        let err = Pipe()
        task.standardOutput = out
        task.standardError = err

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return []
        }

        let data = out.fileHandleForReading.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8) else { return [] }

        var results: [ListeningPort] = []
        var currentPID: Int32? = nil
        var currentCmd: String = ""
        var currentUser: String = ""
        // lsof -F prints lines prefixed by the field letter; a process block starts with 'p'
        // and then carries 'c' and 'L' before the file records which start with 'f' or directly 'P'/'n'.
        var currentProto: String = ""

        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let first = line.first else { continue }
            let rest = String(line.dropFirst())
            switch first {
            case "p":
                currentPID = Int32(rest)
            case "c":
                currentCmd = rest
            case "L":
                currentUser = rest
            case "P":
                currentProto = rest
            case "n":
                // Only consider entries that look like listening sockets.
                // TCP listening entries end with "(LISTEN)"; UDP entries may not include state.
                let isTCPListening = rest.contains("(LISTEN)")
                let isUDP = currentProto.uppercased() == "UDP"
                guard isTCPListening || isUDP else { continue }

                let cleaned = rest.replacingOccurrences(of: " (LISTEN)", with: "")
                // Format: "*:port" or "127.0.0.1:port" or "[::1]:port"
                guard let (local, port) = splitAddressPort(cleaned) else { continue }

                let service = serviceName(for: port, proto: currentProto) ?? currentCmd
                results.append(ListeningPort(
                    service: service,
                    proto: currentProto,
                    port: port,
                    localAddress: local,
                    owner: currentUser.isEmpty ? currentCmd : currentUser,
                    pid: currentPID
                ))
            default:
                break
            }
        }

        // Deduplicate on (proto, port, local, pid)
        var seen = Set<String>()
        var deduped: [ListeningPort] = []
        for p in results {
            let key = "\(p.proto)|\(p.port)|\(p.localAddress)|\(p.pid ?? -1)"
            if seen.insert(key).inserted {
                deduped.append(p)
            }
        }
        return deduped.sorted { ($0.port, $0.proto) < ($1.port, $1.proto) }
    }

    private static func splitAddressPort(_ s: String) -> (String, Int)? {
        // Handle IPv6 "[::1]:80"
        if s.hasPrefix("[") {
            if let closeIdx = s.firstIndex(of: "]") {
                let addr = String(s[s.index(after: s.startIndex)..<closeIdx])
                let afterClose = s.index(after: closeIdx)
                guard afterClose < s.endIndex, s[afterClose] == ":" else { return nil }
                let portStr = String(s[s.index(after: afterClose)...])
                if let p = Int(portStr) { return ("[\(addr)]", p) }
                return nil
            }
            return nil
        }
        // IPv4 "*:80" / "127.0.0.1:80"
        guard let colonIdx = s.lastIndex(of: ":") else { return nil }
        let addr = String(s[..<colonIdx])
        let portStr = String(s[s.index(after: colonIdx)...])
        if let p = Int(portStr) { return (addr, p) }
        return nil
    }

    private static func serviceName(for port: Int, proto: String) -> String? {
        let protoLower = proto.lowercased()
        guard let ent = getservbyport(Int32(htons(UInt16(port))), protoLower) else {
            return nil
        }
        return String(cString: ent.pointee.s_name)
    }

    private static func htons(_ value: UInt16) -> UInt16 {
        return value.bigEndian
    }
}
