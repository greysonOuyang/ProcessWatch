import Foundation
import ProcessWatchC

actor SystemSampler {
    private var previousTicks: PWCPUTicks?
    private var previousMemoryUsed: UInt64?
    private var previousMemoryDate: Date?

    func sample(at date: Date) -> SystemSnapshot {
        var snapshot = SystemSnapshot(sampledAt: date)

        var ticks = PWCPUTicks()
        if pw_read_cpu_ticks(&ticks) {
            if var previous = previousTicks {
                let user = delta(pw_cpu_ticks_user(&ticks), pw_cpu_ticks_user(&previous))
                let system = delta(pw_cpu_ticks_system(&ticks), pw_cpu_ticks_system(&previous))
                let nice = delta(pw_cpu_ticks_nice(&ticks), pw_cpu_ticks_nice(&previous))
                let idle = delta(pw_cpu_ticks_idle(&ticks), pw_cpu_ticks_idle(&previous))
                let busy = user + system + nice
                let total = busy + idle
                snapshot.cpuPercent = total > 0 ? Double(busy) / Double(total) * 100 : 0
            }
            previousTicks = ticks
        }

        var memory = PWMemorySample()
        if pw_read_memory(&memory) {
            let totalBytes = pw_memory_total_bytes(&memory)
            let usedBytes = pw_memory_used_bytes(&memory)
            let wiredBytes = pw_memory_wired_bytes(&memory)
            let compressedBytes = pw_memory_compressed_bytes(&memory)
            let swapUsedBytes = pw_memory_swap_used_bytes(&memory)
            let swapTotalBytes = pw_memory_swap_total_bytes(&memory)
            let reclaimableBytes = pw_memory_reclaimable_bytes(&memory)
            let freeBytes = pw_memory_free_bytes(&memory)
            let pressureLevel = pw_memory_pressure_level(&memory)

            snapshot.memoryTotalBytes = totalBytes
            snapshot.memoryUsedBytes = usedBytes
            snapshot.wiredBytes = wiredBytes
            snapshot.compressedBytes = compressedBytes
            snapshot.swapUsedBytes = swapUsedBytes
            snapshot.swapTotalBytes = swapTotalBytes
            snapshot.reclaimableBytes = reclaimableBytes
            snapshot.freeBytes = freeBytes

            if let previousMemoryUsed, let previousMemoryDate {
                let interval = max(date.timeIntervalSince(previousMemoryDate), 0.001)
                let delta = Int64(usedBytes) - Int64(previousMemoryUsed)
                snapshot.memoryGrowthBytesPerSecond = Double(delta) / interval
            }
            previousMemoryUsed = usedBytes
            previousMemoryDate = date

            let pressure = resolvePressure(
                pressureLevel: pressureLevel,
                totalBytes: totalBytes,
                freeBytes: freeBytes,
                reclaimableBytes: reclaimableBytes,
                swapUsedBytes: swapUsedBytes,
                swapTotalBytes: swapTotalBytes
            )
            snapshot.memoryPressure = pressure.state
            snapshot.memoryPressureIsEstimated = pressure.isEstimated
        }

        switch ProcessInfo.processInfo.thermalState {
        case .nominal: snapshot.thermalState = .nominal
        case .fair: snapshot.thermalState = .fair
        case .serious: snapshot.thermalState = .serious
        case .critical: snapshot.thermalState = .critical
        @unknown default: snapshot.thermalState = .unknown
        }

        return snapshot
    }

    private func resolvePressure(
        pressureLevel: Int32,
        totalBytes: UInt64,
        freeBytes: UInt64,
        reclaimableBytes: UInt64,
        swapUsedBytes: UInt64,
        swapTotalBytes: UInt64
    ) -> (state: MemoryPressureState, isEstimated: Bool) {
        switch pressureLevel {
        case 1: return (.normal, false)
        case 2: return (.warning, false)
        case 4: return (.critical, false)
        default:
            guard totalBytes > 0 else { return (.unknown, true) }
            let immediatelyAvailable = freeBytes + reclaimableBytes
            let availableRatio = Double(immediatelyAvailable) / Double(totalBytes)
            let swapRatio = swapTotalBytes > 0
                ? Double(swapUsedBytes) / Double(swapTotalBytes)
                : 0

            if availableRatio < 0.04 && swapRatio > 0.5 {
                return (.critical, true)
            }
            if availableRatio < 0.10 && swapUsedBytes > 0 {
                return (.warning, true)
            }
            return (.normal, true)
        }
    }

    private func delta(_ current: UInt64, _ previous: UInt64) -> UInt64 {
        current >= previous ? current - previous : 0
    }
}
