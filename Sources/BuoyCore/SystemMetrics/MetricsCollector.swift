import Foundation

/// Aggregates all metric subsystems. Stateful because CPU and per-process CPU
/// are computed as deltas between samples.
public final class MetricsCollector {
    private let cpu = CPUMetricsCollector()
    private let processes = ProcessMetricsCollector()
    private let services: ServiceMetricsCollector

    public init() {
        self.services = ServiceMetricsCollector(processCollector: processes)
    }

    /// Collects a full snapshot. Safe to call from a background queue.
    public func collect() -> DashboardSnapshot {
        let cpuSnap = cpu.sample()
        let memSnap = MemoryMetricsCollector.sample()
        let diskSnap = DiskMetricsCollector.sample()
        let powerSnap = PowerMetricsCollector.sample()
        let thermalSnap = ThermalMetricsCollector.sample()
        let procRows = processes.sample()
        let serviceRows = services.sample(with: procRows)
        let netSnap = NetworkMetricsCollector.sample()

        return DashboardSnapshot(
            capturedAt: Date(),
            cpu: cpuSnap,
            memory: memSnap,
            disk: diskSnap,
            power: powerSnap,
            thermal: thermalSnap,
            processes: procRows,
            services: serviceRows,
            network: netSnap
        )
    }
}
