import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var system = SystemSnapshot()
    @Published private(set) var processes: [ProcessSnapshot] = []
    @Published private(set) var activeAnomalies: [Int32: Set<AnomalyKind>] = [:]
    @Published private(set) var activeGroupAnomalies: [String: Set<AnomalyKind>] = [:]
    @Published private(set) var lastSampleAt: Date?
    @Published var isPaused = false

    let settings = SettingsStore()
    let history = HistoryStore()
    let loginItem = LoginItemService()

    private let processSampler = ProcessSampler()
    private let systemSampler = SystemSampler()
    private let detector = AnomalyDetector()
    private var monitoringTask: Task<Void, Never>?

    var processGroups: [ProcessGroupSnapshot] {
        ProcessGroupSnapshot.grouped(processes)
    }

    var topProcessGroups: [ProcessGroupSnapshot] {
        Array(processGroups.sorted {
            if $0.cpuPercent == $1.cpuPercent {
                if $0.instanceCount == $1.instanceCount {
                    return $0.memoryBytes > $1.memoryBytes
                }
                return $0.instanceCount > $1.instanceCount
            }
            return $0.cpuPercent > $1.cpuPercent
        }.prefix(8))
    }

    var activeAnomalyCount: Int {
        activeAnomalies.count + activeGroupAnomalies.count
    }

    var statusSymbol: String {
        if activeAnomalyCount > 0 { return "exclamationmark.triangle.fill" }
        if system.cpuPercent >= 75 || system.thermalState == .serious || system.thermalState == .critical {
            return "flame.fill"
        }
        return "waveform.path.ecg"
    }

    init() {
        NotificationService.shared.requestAuthorization()
        startMonitoring()
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
}
