import Foundation

private let byteFormatter: ByteCountFormatter = {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
    formatter.countStyle = .memory
    formatter.includesUnit = true
    formatter.isAdaptive = true
    return formatter
}()

func formatBytes(_ bytes: UInt64) -> String {
    byteFormatter.string(fromByteCount: bytes > UInt64(Int64.max) ? Int64.max : Int64(bytes))
}

func formatRate(_ bytesPerSecond: Double) -> String {
    guard abs(bytesPerSecond) >= 1 else { return "0 B/s" }
    return "\(byteFormatter.string(fromByteCount: Int64(abs(bytesPerSecond))))/s"
}

func formatSignedRate(_ bytesPerSecond: Double) -> String {
    guard abs(bytesPerSecond) >= 1 else { return "稳定" }
    let prefix = bytesPerSecond > 0 ? "+" : "−"
    return "\(prefix)\(formatRate(bytesPerSecond))"
}

func formatPercent(_ value: Double) -> String {
    String(format: value >= 100 ? "%.0f%%" : "%.1f%%", value)
}

func formatDuration(_ interval: TimeInterval) -> String {
    let seconds = max(0, Int(interval))
    if seconds < 60 { return "\(seconds) 秒" }
    let minutes = seconds / 60
    if minutes < 60 { return "\(minutes) 分钟" }
    let hours = minutes / 60
    if hours < 24 { return "\(hours) 小时 \(minutes % 60) 分钟" }
    let days = hours / 24
    return "\(days) 天 \(hours % 24) 小时"
}
