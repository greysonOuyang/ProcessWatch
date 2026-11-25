import Foundation

enum SuspicionLevel: String, Sendable {
  case normal = "正常"
  case observe = "观察"
  case investigate = "需检查"
  case high = "高嫌疑"
}

struct DiagnosisThresholds: Sendable {
  let cpuPercent: Double
  let diskWriteBytesPerSecond: Double
  let processStormInstances: Int
}

struct ProcessGroupDiagnosis: Sendable {
  let score: Int
  let level: SuspicionLevel
  let summary: String
  let evidence: [String]
  let recommendedAction: String
}

enum ProcessDiagnosisEngine {
  static func diagnose(
    group: ProcessGroupSnapshot,
    kinds: Set<AnomalyKind>,
    thresholds: DiagnosisThresholds
  ) -> ProcessGroupDiagnosis {
    var score = 0
    var evidence: [String] = []

    if kinds.contains(.repoHarnessLeak) {
      score += 45
      evidence.append("已满足 repo-harness 专用泄漏规则")
    }
    if kinds.contains(.processStorm) {
      score += 35
      evidence.append("同一可执行文件的实例数持续超过阈值")
    }
    if kinds.contains(.memoryGrowth) {
      score += 35
      evidence.append("观察窗口内内存持续增长，已达到告警条件")
    }
    if kinds.contains(.cpu) {
      score += 30
      evidence.append("至少一个实例持续高 CPU，已达到告警条件")
    }
    if kinds.contains(.diskWrite) {
      score += 25
      evidence.append("至少一个实例持续写盘，已达到告警条件")
    }

    let cpuThreshold = max(1, thresholds.cpuPercent)
    if !kinds.contains(.cpu) {
      if group.cpuPercent >= cpuThreshold {
        score += 18
        evidence.append("当前 CPU 合计为 \(formatPercent(group.cpuPercent))，但尚未持续到告警时长")
      } else if group.cpuPercent >= cpuThreshold * 0.65 {
        score += 8
        evidence.append("当前 CPU 合计偏高：\(formatPercent(group.cpuPercent))")
      }
    }

    if !kinds.contains(.processStorm), group.instanceCount > thresholds.processStormInstances {
      score += 15
      evidence.append("当前存在 \(group.instanceCount) 个同路径实例，正在确认是否持续增长")
    }

    if !kinds.contains(.diskWrite),
      group.diskWriteBytesPerSecond >= max(1, thresholds.diskWriteBytesPerSecond)
    {
      score += 10
      evidence.append("当前写入速率较高：\(formatRate(group.diskWriteBytesPerSecond))")
    }

    if group.memoryBytes >= 2 * 1_073_741_824 {
      score += 5
      evidence.append("当前占用 \(formatBytes(group.memoryBytes))；高占用本身不等于内存泄漏")
    }

    if let affiliation = group.affiliationSummary {
      evidence.append("调用链归属：\(affiliation)")
    }

    let boundedScore = min(100, score)
    let level: SuspicionLevel
    switch boundedScore {
    case 70...: level = .high
    case 40...: level = .investigate
    case 20...: level = .observe
    default: level = .normal
    }

    let summary: String
    if kinds.contains(.repoHarnessLeak) {
      summary = "高置信度疑似残留进程：专用生命周期证据与异常实例规模同时成立。"
    } else if kinds.contains(.memoryGrowth) {
      summary = "疑似内存泄漏：外部监测确认持续增长，但仍需结合应用内部分析才能定性。"
    } else if kinds.contains(.processStorm) {
      summary = "疑似重复启动或回收失败：同一路径进程实例持续过多。"
    } else if kinds.contains(.cpu) {
      summary = "疑似 CPU 失控：高占用已经持续超过配置时长。"
    } else if kinds.contains(.diskWrite) {
      summary = "疑似写盘循环：磁盘写入已经持续超过配置时长。"
    } else if boundedScore >= 20 {
      summary = "当前资源行为值得观察，但尚未形成持续异常。"
    } else {
      summary = "当前没有足够证据将该进程组判定为异常。"
    }

    let recommendedAction: String
    if group.actionableProcessCount == 0 {
      recommendedAction = "该组当前没有通过安全校验的可操作进程；请仅查看详情或使用活动监视器继续调查。"
    } else if kinds.contains(.repoHarnessLeak) {
      recommendedAction = "先核对生命周期证据与完整命令，仅对已通过身份校验的当前用户进程执行操作。"
    } else if kinds.contains(.cpu) || kinds.contains(.memoryGrowth) || kinds.contains(.diskWrite) {
      recommendedAction = "先核对完整命令和工作目录，再优雅结束通过身份校验的异常实例；复查无效后才强制退出。"
    } else if kinds.contains(.processStorm) {
      recommendedAction = "展开实例确认重复来源；PPID = 1 只表示由 launchd 管理，不能单独作为清理依据。"
    } else {
      recommendedAction = "继续观察，不建议仅因瞬时占用、进程数量或 PPID = 1 而清理。"
    }

    return ProcessGroupDiagnosis(
      score: boundedScore,
      level: level,
      summary: summary,
      evidence: evidence.isEmpty ? ["未达到持续异常阈值"] : evidence,
      recommendedAction: recommendedAction
    )
  }
}

struct IncidentSuspect: Codable, Hashable, Identifiable, Sendable {
  let groupID: String
  let name: String
  let path: String
  let score: Int
  let cpuPercent: Double
  let memoryBytes: UInt64
  let instanceCount: Int
  let launchdManagedCount: Int
  let actionableProcessCount: Int

  var id: String { groupID }

  private enum CodingKeys: String, CodingKey {
    case groupID
    case name
    case path
    case score
    case cpuPercent
    case memoryBytes
    case instanceCount
    case launchdManagedCount
    case actionableProcessCount
    case orphanCount
  }

  init(
    groupID: String,
    name: String,
    path: String,
    score: Int,
    cpuPercent: Double,
    memoryBytes: UInt64,
    instanceCount: Int,
    launchdManagedCount: Int,
    actionableProcessCount: Int
  ) {
    self.groupID = groupID
    self.name = name
    self.path = path
    self.score = score
    self.cpuPercent = cpuPercent
    self.memoryBytes = memoryBytes
    self.instanceCount = instanceCount
    self.launchdManagedCount = launchdManagedCount
    self.actionableProcessCount = actionableProcessCount
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    groupID = try container.decode(String.self, forKey: .groupID)
    name = try container.decode(String.self, forKey: .name)
    path = try container.decode(String.self, forKey: .path)
    score = try container.decode(Int.self, forKey: .score)
    cpuPercent = try container.decode(Double.self, forKey: .cpuPercent)
    memoryBytes = try container.decode(UInt64.self, forKey: .memoryBytes)
    instanceCount = try container.decode(Int.self, forKey: .instanceCount)
    launchdManagedCount = try container.decodeIfPresent(Int.self, forKey: .launchdManagedCount)
      ?? container.decodeIfPresent(Int.self, forKey: .orphanCount)
      ?? 0
    actionableProcessCount = try container.decodeIfPresent(Int.self, forKey: .actionableProcessCount) ?? 0
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(groupID, forKey: .groupID)
    try container.encode(name, forKey: .name)
    try container.encode(path, forKey: .path)
    try container.encode(score, forKey: .score)
    try container.encode(cpuPercent, forKey: .cpuPercent)
    try container.encode(memoryBytes, forKey: .memoryBytes)
    try container.encode(instanceCount, forKey: .instanceCount)
    try container.encode(launchdManagedCount, forKey: .launchdManagedCount)
    try container.encode(actionableProcessCount, forKey: .actionableProcessCount)
  }
}

struct ActiveSystemIncident: Identifiable, Sendable {
  let id: UUID
  let startedAt: Date
  var lastUpdatedAt: Date
  var peakCPUPercent: Double
  var worstThermalState: ThermalState
  var worstMemoryPressure: MemoryPressureState
  var reasons: [String]
  var suspects: [IncidentSuspect]

  func duration(at date: Date = .now) -> TimeInterval {
    max(0, date.timeIntervalSince(startedAt))
  }
}

struct SystemIncidentRecord: Codable, Identifiable, Sendable {
  let id: UUID
  let startedAt: Date
  let endedAt: Date
  let peakCPUPercent: Double
  let worstThermalState: ThermalState
  let worstMemoryPressure: MemoryPressureState
  let reasons: [String]
  let suspects: [IncidentSuspect]

  var duration: TimeInterval {
    max(0, endedAt.timeIntervalSince(startedAt))
  }
}

extension ThermalState {
  var severityRank: Int {
    switch self {
    case .nominal: return 0
    case .fair: return 1
    case .serious: return 2
    case .critical: return 3
    case .unknown: return -1
    }
  }

  static func worst(_ lhs: ThermalState, _ rhs: ThermalState) -> ThermalState {
    lhs.severityRank >= rhs.severityRank ? lhs : rhs
  }
}

extension MemoryPressureState {
  var severityRank: Int {
    switch self {
    case .normal: return 0
    case .warning: return 1
    case .critical: return 2
    case .unknown: return -1
    }
  }

  static func worst(_ lhs: MemoryPressureState, _ rhs: MemoryPressureState) -> MemoryPressureState {
    lhs.severityRank >= rhs.severityRank ? lhs : rhs
  }
}
