import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
  @Published private(set) var system = SystemSnapshot()
  @Published private(set) var processes: [ProcessSnapshot] = []
  @Published private(set) var activeAnomalies: [Int32: Set<AnomalyKind>] = [:]
  @Published private(set) var activeGroupAnomalies: [String: Set<AnomalyKind>] = [:]
  @Published private(set) var activeIncident: ActiveSystemIncident?
  @Published private(set) var lastSampleAt: Date?
  @Published private(set) var cpuHistory: [MetricPoint] = []
  @Published private(set) var memoryHistory: [MetricPoint] = []
  @Published private(set) var diskWriteHistory: [MetricPoint] = []
  @Published private(set) var processCountHistory: [MetricPoint] = []
  @Published var isPaused = false
  @Published var selectedSection: AppSection = .overview

  let settings = SettingsStore()
  let history = HistoryStore()
  let incidentHistory = IncidentHistoryStore()
  let actionHistory = ActionHistoryStore()
  let loginItem = LoginItemService()

  private let processSampler = ProcessSampler()
  private let systemSampler = SystemSampler()
  private let detector = AnomalyDetector()
  private var monitoringTask: Task<Void, Never>?

  var processGroups: [ProcessGroupSnapshot] {
    ProcessGroupSnapshot.grouped(processes)
  }

  var rankedProcessGroups: [ProcessGroupSnapshot] {
    processGroups.sorted { lhs, rhs in
      let lhsScore = diagnosis(for: lhs).score
      let rhsScore = diagnosis(for: rhs).score
      if lhsScore != rhsScore { return lhsScore > rhsScore }
      return Self.groupPriority(lhs, rhs)
    }
  }

  var topProcessGroups: [ProcessGroupSnapshot] {
    Array(rankedProcessGroups.prefix(10))
  }

  var anomalousGroups: [ProcessGroupSnapshot] {
    processGroups
      .filter { !anomalyKinds(for: $0).isEmpty }
      .sorted { lhs, rhs in
        let lhsScore = diagnosis(for: lhs).score
        let rhsScore = diagnosis(for: rhs).score
        if lhsScore != rhsScore { return lhsScore > rhsScore }
        return Self.groupPriority(lhs, rhs)
      }
  }

  var actionableAnomalousGroups: [ProcessGroupSnapshot] {
    anomalousGroups.filter { $0.actionableProcessCount > 0 }
  }

  var anomalyContributorGroupCount: Int {
    anomalousGroups.count
  }

  var actionableAnomalyGroupCount: Int {
    actionableAnomalousGroups.count
  }

  var suggestedActionGroup: ProcessGroupSnapshot? {
    actionableAnomalousGroups.first
  }

  var recentIncident: SystemIncidentRecord? {
    guard let incident = incidentHistory.incidents.first,
      Date().timeIntervalSince(incident.endedAt) <= 6 * 60 * 60
    else { return nil }
    return incident
  }

  var activeAnomalyCount: Int {
    let processCount = activeAnomalies.values.reduce(0) { $0 + $1.count }
    let groupCount = activeGroupAnomalies.values.reduce(0) { $0 + $1.count }
    return processCount + groupCount
  }

  var totalDiskWriteBytesPerSecond: Double {
    processes.reduce(0) { $0 + $1.diskWriteBytesPerSecond }
  }

  var totalDiskReadBytesPerSecond: Double {
    processes.reduce(0) { $0 + $1.diskReadBytesPerSecond }
  }

  var totalLaunchdManagedCount: Int {
    processes.reduce(0) { $0 + ($1.isLaunchdManaged ? 1 : 0) }
  }

  var statusSymbol: String {
    if activeIncident != nil || activeAnomalyCount > 0 { return "exclamationmark.triangle.fill" }
    if system.cpuPercent >= 75 || system.thermalState == .serious
      || system.thermalState == .critical
    {
      return "flame.fill"
    }
    return "waveform.path.ecg"
  }

  init() {
    NotificationService.shared.onOpenAlerts = { [weak self] in
      guard let self else { return }
      self.selectedSection = .alerts
      WindowManager.shared.show(model: self)
    }
    NotificationService.shared.requestAuthorization()
    startMonitoring()
  }

  deinit {
    monitoringTask?.cancel()
  }

  func startMonitoring() {
    guard monitoringTask == nil else { return }
    monitoringTask = Task { [weak self] in
      while !Task.isCancelled {
        guard let self else { return }

        if self.isPaused {
          try? await Task.sleep(nanoseconds: 1_000_000_000)
          continue
        }

        await self.refresh(at: Date())
        let interval = max(1, self.settings.samplingInterval)
        try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
      }
    }
  }

  func togglePaused() {
    isPaused.toggle()
  }

  func anomalyKinds(for process: ProcessSnapshot) -> Set<AnomalyKind> {
    activeAnomalies[process.pid] ?? []
  }

  func anomalyKinds(for group: ProcessGroupSnapshot) -> Set<AnomalyKind> {
    let groupKinds = activeGroupAnomalies[group.id] ?? []
    let processKinds = group.processes.reduce(into: Set<AnomalyKind>()) { result, process in
      result.formUnion(activeAnomalies[process.pid] ?? [])
    }
    return groupKinds.union(processKinds)
  }

  func diagnosis(for group: ProcessGroupSnapshot) -> ProcessGroupDiagnosis {
    ProcessDiagnosisEngine.diagnose(
      group: group,
      kinds: anomalyKinds(for: group),
      thresholds: DiagnosisThresholds(
        cpuPercent: settings.cpuThreshold,
        diskWriteBytesPerSecond: settings.diskWriteMBps * 1_048_576,
        processStormInstances: Int(settings.processStormInstanceThreshold)
      )
    )
  }

  func group(id: String?) -> ProcessGroupSnapshot? {
    guard let id else { return nil }
    return processGroups.first { $0.id == id }
  }

  func verifyProcessAction(
    _ report: ProcessActionReport,
    originalGroup: ProcessGroupSnapshot
  ) async -> ProcessRecoveryAssessment {
    let beforeSystem = system
    let beforeGroupCPU = originalGroup.cpuPercent
    let beforeGroupMemory = originalGroup.memoryBytes

    if report.attempted > 0 {
      let delay = max(2, min(6, settings.samplingInterval + 1))
      try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
      await refresh(at: Date())
    }

    let remaining = report.signaledPIDs.filter(ProcessActionService.isProcessRunning)
    let exited = report.signaledPIDs.filter { !remaining.contains($0) }
    let refreshedGroup = group(id: originalGroup.id)

    return ProcessRecoveryAssessment(
      report: report,
      verifiedAt: .now,
      exitedPIDs: exited,
      remainingPIDs: remaining,
      beforeGroupCPUPercent: beforeGroupCPU,
      afterGroupCPUPercent: refreshedGroup?.cpuPercent ?? 0,
      beforeGroupMemoryBytes: beforeGroupMemory,
      afterGroupMemoryBytes: refreshedGroup?.memoryBytes ?? 0,
      beforeSystemCPUPercent: beforeSystem.cpuPercent,
      afterSystemCPUPercent: system.cpuPercent,
      beforeThermalState: beforeSystem.thermalState,
      afterThermalState: system.thermalState
    )
  }

  private func refresh(at now: Date) async {
    async let processResult = processSampler.sample(at: now)
    async let systemResult = systemSampler.sample(at: now)
    let (sampledProcesses, sampledSystem) = await (processResult, systemResult)

    processes = sampledProcesses
    system = sampledSystem
    lastSampleAt = now
    appendHistory(at: now)

    let evaluation = detector.evaluate(
      processes: sampledProcesses,
      settings: settings,
      now: now
    )
    activeAnomalies = evaluation.active
    activeGroupAnomalies = evaluation.activeGroups

    for event in evaluation.events {
      history.add(event)
      if settings.notificationsEnabled {
        NotificationService.shared.send(event: event)
      }
    }

    updateSystemIncident(at: now)
  }

  private func updateSystemIncident(at now: Date) {
    let reasons = incidentReasons
    guard !reasons.isEmpty else {
      closeActiveIncident(at: now)
      return
    }

    let suspects = Array(actionableAnomalousGroups.prefix(3)).map { group in
      let diagnosis = diagnosis(for: group)
      return IncidentSuspect(
        groupID: group.id,
        name: group.name,
        path: group.path,
        score: diagnosis.score,
        cpuPercent: group.cpuPercent,
        memoryBytes: group.memoryBytes,
        instanceCount: group.instanceCount,
        launchdManagedCount: group.launchdManagedCount,
        actionableProcessCount: group.actionableProcessCount
      )
    }

    if var incident = activeIncident {
      incident.lastUpdatedAt = now
      incident.peakCPUPercent = max(incident.peakCPUPercent, system.cpuPercent)
      incident.worstThermalState = .worst(incident.worstThermalState, system.thermalState)
      incident.worstMemoryPressure = .worst(incident.worstMemoryPressure, system.memoryPressure)
      incident.reasons = reasons
      incident.suspects = suspects
      activeIncident = incident
    } else {
      activeIncident = ActiveSystemIncident(
        id: UUID(),
        startedAt: now,
        lastUpdatedAt: now,
        peakCPUPercent: system.cpuPercent,
        worstThermalState: system.thermalState,
        worstMemoryPressure: system.memoryPressure,
        reasons: reasons,
        suspects: suspects
      )
    }
  }

  private var incidentReasons: [String] {
    var reasons: [String] = []
    let systemCPUThreshold = max(70, min(95, settings.cpuThreshold))
    if system.cpuPercent >= systemCPUThreshold {
      reasons.append("系统 CPU \(formatPercent(system.cpuPercent))")
    }
    switch system.thermalState {
    case .serious, .critical:
      reasons.append("热状态\(system.thermalState.rawValue)")
    case .fair where system.cpuPercent >= 55:
      reasons.append("温控压力升高")
    default:
      break
    }
    if system.memoryPressure == .critical {
      reasons.append("内存压力严重")
    }
    if activeAnomalyCount > 0 {
      reasons.append("检测到 \(activeAnomalyCount) 个持续异常信号")
    }
    return reasons
  }

  private func closeActiveIncident(at now: Date) {
    guard let incident = activeIncident else { return }
    activeIncident = nil

    let minimumDuration = max(10, settings.samplingInterval * 2)
    guard incident.duration(at: now) >= minimumDuration else { return }
    incidentHistory.add(
      SystemIncidentRecord(
        id: incident.id,
        startedAt: incident.startedAt,
        endedAt: now,
        peakCPUPercent: incident.peakCPUPercent,
        worstThermalState: incident.worstThermalState,
        worstMemoryPressure: incident.worstMemoryPressure,
        reasons: incident.reasons,
        suspects: incident.suspects
      )
    )
  }

  private func appendHistory(at date: Date) {
    cpuHistory.appendSample(system.cpuPercent, at: date)
    memoryHistory.appendSample(system.memoryPercent, at: date)
    diskWriteHistory.appendSample(totalDiskWriteBytesPerSecond, at: date)
    processCountHistory.appendSample(Double(processes.count), at: date)
  }

  private static func groupPriority(_ lhs: ProcessGroupSnapshot, _ rhs: ProcessGroupSnapshot)
    -> Bool
  {
    if lhs.cpuPercent == rhs.cpuPercent {
      if lhs.instanceCount == rhs.instanceCount {
        return lhs.memoryBytes > rhs.memoryBytes
      }
      return lhs.instanceCount > rhs.instanceCount
    }
    return lhs.cpuPercent > rhs.cpuPercent
  }
}
