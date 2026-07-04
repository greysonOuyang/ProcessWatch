import Foundation

struct SystemSnapshot: Sendable {
    var cpuPercent: Double = 0
    var memoryUsedBytes: UInt64 = 0
    var memoryTotalBytes: UInt64 = 0
    var wiredBytes: UInt64 = 0
    var compressedBytes: UInt64 = 0
    var swapUsedBytes: UInt64 = 0
    var swapTotalBytes: UInt64 = 0
    var reclaimableBytes: UInt64 = 0
    var freeBytes: UInt64 = 0
    var memoryGrowthBytesPerSecond: Double = 0
    var memoryPressure: MemoryPressureState = .unknown
    var memoryPressureIsEstimated = false
    var thermalState: ThermalState = .nominal
    var sampledAt: Date = .now

    var memoryPercent: Double {
        guard memoryTotalBytes > 0 else { return 0 }
        return Double(memoryUsedBytes) / Double(memoryTotalBytes) * 100
    }
}

enum MemoryPressureState: String, Codable, Sendable {
    case normal = "正常"
    case warning = "偏高"
    case critical = "严重"
    case unknown = "未知"
}

enum ThermalState: String, Codable, Sendable {
    case nominal = "正常"
    case fair = "偏高"
    case serious = "严重"
    case critical = "临界"
    case unknown = "未知"
}
