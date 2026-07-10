import Foundation

@MainActor
final class AnomalyDetector {
  struct EvaluationResult {
    let events: [AnomalyEvent]
    let active: [Int32: Set<AnomalyKind>]
    let activeGroups: [String: Set<AnomalyKind>]
  }

  private struct MemoryPoint {
    let date: Date
    let bytes: UInt64
  }

  private struct ProcessTracker {
    var name: String
    var cpuHighSince: Date?
    var diskHighSince: Date?
    var memoryPoints: [MemoryPoint] = []
    var activeKinds: Set<AnomalyKind> = []
    var lastAlertAt: [AnomalyKind: Date] = [:]
  }

  private struct GroupTracker {
    var name: String
    var stormSince: Date?
    var activeKinds: Set<AnomalyKind> = []
    var lastAlertAt: [AnomalyKind: Date] = [:]
  }

  private var processTrackers: [Int32: ProcessTracker] = [:]
  private var groupTrackers: [String: GroupTracker] = [:]
  private let cooldown: TimeInterval = 30 * 60

  func evaluate(
    processes: [ProcessSnapshot],
    settings: SettingsStore,
    now: Date
  ) -> EvaluationResult {
    var generated: [AnomalyEvent] = []
    evaluateProcesses(processes, settings: settings, now: now, generated: &generated)
    evaluateGroups(
      ProcessGroupSnapshot.grouped(processes), settings: settings, now: now, generated: &generated)

    let activeProcesses = processTrackers.reduce(into: [Int32: Set<AnomalyKind>]()) {
      result, entry in
      if !entry.value.activeKinds.isEmpty {
        result[entry.key] = entry.value.activeKinds
      }
    }
    let activeGroups = groupTrackers.reduce(into: [String: Set<AnomalyKind>]()) { result, entry in
      if !entry.value.activeKinds.isEmpty {
        result[entry.key] = entry.value.activeKinds
      }
    }

    return EvaluationResult(events: generated, active: activeProcesses, activeGroups: activeGroups)
  }

  private func evaluateProcesses(
    _ processes: [ProcessSnapshot],
    settings: SettingsStore,
    now: Date,
    generated: inout [AnomalyEvent]
  ) {
    let visiblePIDs = Set(processes.map(\.pid))
    processTrackers = processTrackers.filter { visiblePIDs.contains($0.key) }

    for process in processes {
      if settings.isSuppressed(process, now: now) {
        processTrackers.removeValue(forKey: process.pid)
        continue
      }

      var tracker = processTrackers[process.pid] ?? ProcessTracker(name: process.name)
      if tracker.name != process.name {
        tracker = ProcessTracker(name: process.name)
      }

      evaluateCPU(process, tracker: &tracker, settings: settings, now: now, generated: &generated)
      evaluateDisk(process, tracker: &tracker, settings: settings, now: now, generated: &generated)
      evaluateMemory(
        process, tracker: &tracker, settings: settings, now: now, generated: &generated)
      processTrackers[process.pid] = tracker
    }
  }

  private func evaluateGroups(
    _ groups: [ProcessGroupSnapshot],
    settings: SettingsStore,
    now: Date,
    generated: inout [AnomalyEvent]
  ) {
    let visibleGroups = Set(groups.map(\.id))
    groupTrackers = groupTrackers.filter { visibleGroups.contains($0.key) }
    let threshold = Int(settings.processStormInstanceThreshold)

    for group in groups {
      if settings.isSuppressed(group, now: now) {
        groupTrackers.removeValue(forKey: group.id)
        continue
      }

      var tracker = groupTrackers[group.id] ?? GroupTracker(name: group.name)
      if tracker.name != group.name {
        tracker = GroupTracker(name: group.name)
      }

      let isStorm = group.instanceCount > threshold
      if isStorm {
        tracker.stormSince = tracker.stormSince ?? now
        if let since = tracker.stormSince,
          now.timeIntervalSince(since) >= settings.processStormDuration
        {
          let shouldNotify = shouldAlert(.processStorm, tracker: tracker, now: now)
          tracker.activeKinds.insert(.processStorm)
          if shouldNotify {
            generated.append(
              makeGroupEvent(
                group: group,
                kind: .processStorm,
                title: "检测到进程风暴",
                detail:
                  "同一可执行文件存在 \(group.instanceCount) 个实例，CPU 合计 \(formatPercent(group.cpuPercent))，内存合计 \(formatBytes(group.memoryBytes))，其中孤儿进程 \(group.orphanCount) 个，已持续约 \(formatDuration(now.timeIntervalSince(since)))。"
              ))
            tracker.lastAlertAt[.processStorm] = now
          }
        }
      } else {
        tracker.stormSince = nil
        tracker.activeKinds.remove(.processStorm)
      }

      let repoHarnessOrphans = group.processes.filter {
        $0.isOrphan && $0.affiliation.belongsToRepoHarness
          && $0.runtime >= settings.repoHarnessOrphanDuration
      }
      let isRepoHarnessLeak = isStorm && !repoHarnessOrphans.isEmpty

      if isRepoHarnessLeak {
        let shouldNotify = shouldAlert(.repoHarnessLeak, tracker: tracker, now: now)
        tracker.activeKinds.insert(.repoHarnessLeak)
        if shouldNotify {
          generated.append(
            makeGroupEvent(
              group: group,
              kind: .repoHarnessLeak,
              title: "repo-harness 疑似进程泄漏",
              detail:
                "检测到 \(repoHarnessOrphans.count) 个运行超过 \(formatDuration(settings.repoHarnessOrphanDuration)) 的孤儿 \(group.name) 进程；同一可执行文件当前共有 \(group.instanceCount) 个实例。"
            ))
          tracker.lastAlertAt[.repoHarnessLeak] = now
        }
      } else {
        tracker.activeKinds.remove(.repoHarnessLeak)
      }

      groupTrackers[group.id] = tracker
    }
  }

  private func evaluateCPU(
    _ process: ProcessSnapshot,
    tracker: inout ProcessTracker,
    settings: SettingsStore,
    now: Date,
    generated: inout [AnomalyEvent]
  ) {
    if process.cpuPercent >= settings.cpuThreshold {
      tracker.cpuHighSince = tracker.cpuHighSince ?? now
      if let since = tracker.cpuHighSince,
        now.timeIntervalSince(since) >= settings.cpuDuration
      {
        let shouldNotify = shouldAlert(.cpu, tracker: tracker, now: now)
        tracker.activeKinds.insert(.cpu)
        if shouldNotify {
          generated.append(
            makeEvent(
              process: process,
              kind: .cpu,
              title: "发现持续高 CPU 进程",
              detail:
                "CPU \(formatPercent(process.cpuPercent))，已持续约 \(formatDuration(now.timeIntervalSince(since)))。"
            ))
          tracker.lastAlertAt[.cpu] = now
        }
      }
    } else {
      tracker.cpuHighSince = nil
      tracker.activeKinds.remove(.cpu)
    }
  }

  private func evaluateDisk(
    _ process: ProcessSnapshot,
    tracker: inout ProcessTracker,
    settings: SettingsStore,
    now: Date,
    generated: inout [AnomalyEvent]
  ) {
    let threshold = settings.diskWriteMBps * 1_048_576
    if process.diskWriteBytesPerSecond >= threshold {
      tracker.diskHighSince = tracker.diskHighSince ?? now
      if let since = tracker.diskHighSince,
        now.timeIntervalSince(since) >= settings.diskDuration
      {
        let shouldNotify = shouldAlert(.diskWrite, tracker: tracker, now: now)
        tracker.activeKinds.insert(.diskWrite)
        if shouldNotify {
          generated.append(
            makeEvent(
              process: process,
              kind: .diskWrite,
              title: "发现持续写盘进程",
              detail:
                "当前写入 \(formatRate(process.diskWriteBytesPerSecond))，已持续约 \(formatDuration(now.timeIntervalSince(since)))。"
            ))
          tracker.lastAlertAt[.diskWrite] = now
        }
      }
    } else {
      tracker.diskHighSince = nil
      tracker.activeKinds.remove(.diskWrite)
    }
  }

  private func evaluateMemory(
    _ process: ProcessSnapshot,
    tracker: inout ProcessTracker,
    settings: SettingsStore,
    now: Date,
    generated: inout [AnomalyEvent]
  ) {
    tracker.memoryPoints.append(MemoryPoint(date: now, bytes: process.memoryBytes))
    let retentionStart = now.addingTimeInterval(
      -settings.memoryWindow - max(30, settings.samplingInterval * 3))
    tracker.memoryPoints.removeAll { $0.date < retentionStart }

    guard let baseline = tracker.memoryPoints.first,
      now.timeIntervalSince(baseline.date) >= settings.memoryWindow * 0.9
    else {
      return
    }

    let growth = process.memoryBytes >= baseline.bytes ? process.memoryBytes - baseline.bytes : 0
    let threshold = UInt64(max(0, settings.memoryGrowthMB) * 1_048_576)

    if growth >= threshold {
      let shouldNotify = shouldAlert(.memoryGrowth, tracker: tracker, now: now)
      tracker.activeKinds.insert(.memoryGrowth)
      if shouldNotify {
        generated.append(
          makeEvent(
            process: process,
            kind: .memoryGrowth,
            title: "发现内存持续增长进程",
            detail:
              "约 \(formatDuration(now.timeIntervalSince(baseline.date))) 内增长 \(formatBytes(growth))，当前占用 \(formatBytes(process.memoryBytes))。"
          ))
        tracker.lastAlertAt[.memoryGrowth] = now
      }
    } else if growth < threshold / 2 {
      tracker.activeKinds.remove(.memoryGrowth)
    }
  }

  private func shouldAlert(_ kind: AnomalyKind, tracker: ProcessTracker, now: Date) -> Bool {
    guard !tracker.activeKinds.contains(kind) else { return false }
    guard let last = tracker.lastAlertAt[kind] else { return true }
    return now.timeIntervalSince(last) >= cooldown
  }

  private func shouldAlert(_ kind: AnomalyKind, tracker: GroupTracker, now: Date) -> Bool {
    guard !tracker.activeKinds.contains(kind) else { return false }
    guard let last = tracker.lastAlertAt[kind] else { return true }
    return now.timeIntervalSince(last) >= cooldown
  }

  private func makeEvent(
    process: ProcessSnapshot,
    kind: AnomalyKind,
    title: String,
    detail: String
  ) -> AnomalyEvent {
    AnomalyEvent(
      pid: process.pid,
      processName: process.name,
      processPath: process.path,
      kind: kind,
      title: title,
      detail: detail,
      cpuPercent: process.cpuPercent,
      memoryBytes: process.memoryBytes,
      diskWriteBytesPerSecond: process.diskWriteBytesPerSecond
    )
  }

  private func makeGroupEvent(
    group: ProcessGroupSnapshot,
    kind: AnomalyKind,
    title: String,
    detail: String
  ) -> AnomalyEvent {
    let representative = group.representative
    return AnomalyEvent(
      pid: representative?.pid ?? 0,
      processName: "\(group.name) × \(group.instanceCount)",
      processPath: group.path,
      kind: kind,
      title: title,
      detail: detail,
      cpuPercent: group.cpuPercent,
      memoryBytes: group.memoryBytes,
      diskWriteBytesPerSecond: group.diskWriteBytesPerSecond
    )
  }
}
