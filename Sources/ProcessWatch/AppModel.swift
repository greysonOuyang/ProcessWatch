import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
  @Published private(set) var system = SystemSnapshot()
  @Published private(set) var processes: [ProcessSnapshot] = []
  @Published private(set) var activeAnomalies: [Int32: Set<AnomalyKind>] = [:]
  @Published private(set) var activeGroupAnomalies: [String: Set<AnomalyKind>] = [:]
  @Published private(set) var lastSampleAt: Date?
  @Published private(set) var cpuHistory: [MetricPoint] = []
  @Published private(set) var memoryHistory: [MetricPoint] = []
  @Published private(set) var diskWriteHistory: [MetricPoint] = []
  @Published private(set) var processCountHistory: [MetricPoint] = []
  @Published var isPaused = false
  @Published var selectedSection: AppSection = .overview

  let settings = SettingsStore()
  let history = HistoryStore()
  let actionHistory = ActionHistoryStore()
  let loginItem = LoginItemService()

  private let processSampler = ProcessSampler()
  private let systemSampler = SystemSampler()
  private let detector = AnomalyDetector()
  private var monitoringTask: Task<Void, Never>?

  var processGroups: [ProcessGroupSnapshot] {
    ProcessGroupSnapshot.grouped(processes)
  }

  var topProcessGroups: [ProcessGroupSnapshot] {
    Array(processGroups.sorted(by: Self.groupPriority).prefix(10))
  }

  var anomalousGroups: [ProcessGroupSnapshot] {
    processGroups.filter { !anomalyKinds(for: $0).isEmpty }.sorted(by: Self.groupPriority)
  }

  var suggestedActionGroup: ProcessGroupSnapshot? {
    anomalousGroups.first ?? topProcessGroups.first
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

  var totalOrphanCount: Int {
    processes.reduce(0) { $0 + ($1.isOrphan ? 1 : 0) }
  }

  var statusSymbol: String {
    if activeAnomalyCount > 0 { return "exclamationmark.triangle.fill" }
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

        let now = Date()
        async let processResult = self.processSampler.sample(at: now)
        async let systemResult = self.systemSampler.sample(at: now)
        let (sampledProcesses, sampledSystem) = await (processResult, systemResult)

        self.processes = sampledProcesses
        self.system = sampledSystem
        self.lastSampleAt = now
        self.appendHistory(at: now)

        let evaluation = self.detector.evaluate(
          processes: sampledProcesses,
          settings: self.settings,
          now: now
        )
        self.activeAnomalies = evaluation.active
        self.activeGroupAnomalies = evaluation.activeGroups

        for event in evaluation.events {
          self.history.add(event)
          if self.settings.notificationsEnabled {
            NotificationService.shared.send(event: event)
          }
        }

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

  func group(id: String?) -> ProcessGroupSnapshot? {
    guard let id else { return nil }
    return processGroups.first { $0.id == id }
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
