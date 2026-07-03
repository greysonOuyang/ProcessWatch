import Foundation

enum AnomalyKind: String, Codable, CaseIterable, Sendable {
    case cpu = "CPU 持续高占用"
    case memoryGrowth = "内存持续增长"
    case diskWrite = "磁盘持续写入"
    case processStorm = "进程风暴"
    case repoHarnessLeak = "repo-harness 进程泄漏"
}

struct AnomalyEvent: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let date: Date
    let pid: Int32
    let processName: String
    let processPath: String
    let kind: AnomalyKind
    let title: String
    let detail: String
    let cpuPercent: Double
    let memoryBytes: UInt64
    let diskWriteBytesPerSecond: Double

    init(
        id: UUID = UUID(),
        date: Date = .now,
        pid: Int32,
        processName: String,
        processPath: String,
        kind: AnomalyKind,
        title: String,
        detail: String,
        cpuPercent: Double,
        memoryBytes: UInt64,
        diskWriteBytesPerSecond: Double
    ) {
        self.id = id
        self.date = date
        self.pid = pid
        self.processName = processName
        self.processPath = processPath
        self.kind = kind
        self.title = title
        self.detail = detail
        self.cpuPercent = cpuPercent
        self.memoryBytes = memoryBytes
        self.diskWriteBytesPerSecond = diskWriteBytesPerSecond
    }
}
