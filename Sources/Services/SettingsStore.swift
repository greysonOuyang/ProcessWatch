import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    private enum Key {
        static let cpuThreshold = "cpuThreshold"
        static let cpuDuration = "cpuDuration"
        static let memoryGrowthMB = "memoryGrowthMB"
        static let memoryWindow = "memoryWindow"
        static let diskWriteMBps = "diskWriteMBps"
        static let diskDuration = "diskDuration"
        static let processStormInstanceThreshold = "processStormInstanceThreshold"
        static let processStormDuration = "processStormDuration"
        static let repoHarnessOrphanDuration = "repoHarnessOrphanDuration"
        static let samplingInterval = "samplingInterval"
        static let notificationsEnabled = "notificationsEnabled"
        static let ignoredProcessNames = "ignoredProcessNames"
    }

    private let defaults: UserDefaults
    private var isLoading = true

    @Published var cpuThreshold: Double { didSet { save(Key.cpuThreshold, cpuThreshold) } }
    @Published var cpuDuration: TimeInterval { didSet { save(Key.cpuDuration, cpuDuration) } }
    @Published var memoryGrowthMB: Double { didSet { save(Key.memoryGrowthMB, memoryGrowthMB) } }
    @Published var memoryWindow: TimeInterval { didSet { save(Key.memoryWindow, memoryWindow) } }
    @Published var diskWriteMBps: Double { didSet { save(Key.diskWriteMBps, diskWriteMBps) } }
    @Published var diskDuration: TimeInterval { didSet { save(Key.diskDuration, diskDuration) } }
    @Published var processStormInstanceThreshold: Double { didSet { save(Key.processStormInstanceThreshold, processStormInstanceThreshold) } }
    @Published var processStormDuration: TimeInterval { didSet { save(Key.processStormDuration, processStormDuration) } }
    @Published var repoHarnessOrphanDuration: TimeInterval { didSet { save(Key.repoHarnessOrphanDuration, repoHarnessOrphanDuration) } }
    @Published var samplingInterval: TimeInterval { didSet { save(Key.samplingInterval, samplingInterval) } }
    @Published var notificationsEnabled: Bool { didSet { save(Key.notificationsEnabled, notificationsEnabled) } }
    @Published private(set) var ignoredProcessNames: Set<String>

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.cpuThreshold: 80.0,
            Key.cpuDuration: 120.0,
            Key.memoryGrowthMB: 1024.0,
            Key.memoryWindow: 600.0,
            Key.diskWriteMBps: 30.0,
            Key.diskDuration: 120.0,
            Key.processStormInstanceThreshold: 10.0,
            Key.processStormDuration: 120.0,
            Key.repoHarnessOrphanDuration: 600.0,
            Key.samplingInterval: 5.0,
            Key.notificationsEnabled: true
        ])

        cpuThreshold = defaults.double(forKey: Key.cpuThreshold)
        cpuDuration = defaults.double(forKey: Key.cpuDuration)
        memoryGrowthMB = defaults.double(forKey: Key.memoryGrowthMB)
        memoryWindow = defaults.double(forKey: Key.memoryWindow)
        diskWriteMBps = defaults.double(forKey: Key.diskWriteMBps)
        diskDuration = defaults.double(forKey: Key.diskDuration)
        processStormInstanceThreshold = defaults.double(forKey: Key.processStormInstanceThreshold)
        processStormDuration = defaults.double(forKey: Key.processStormDuration)
        repoHarnessOrphanDuration = defaults.double(forKey: Key.repoHarnessOrphanDuration)
        samplingInterval = max(1, defaults.double(forKey: Key.samplingInterval))
        notificationsEnabled = defaults.bool(forKey: Key.notificationsEnabled)
        ignoredProcessNames = Set(defaults.stringArray(forKey: Key.ignoredProcessNames) ?? [])
        isLoading = false
    }

    func ignore(_ processName: String) {
        guard !processName.isEmpty else { return }
        ignoredProcessNames.insert(processName)
        persistIgnoredNames()
    }

    func unignore(_ processName: String) {
        ignoredProcessNames.remove(processName)
        persistIgnoredNames()
    }

    func isIgnored(_ processName: String) -> Bool {
        ignoredProcessNames.contains(processName)
    }

    private func persistIgnoredNames() {
        defaults.set(ignoredProcessNames.sorted(), forKey: Key.ignoredProcessNames)
        objectWillChange.send()
    }

    private func save(_ key: String, _ value: Any) {
        guard !isLoading else { return }
        defaults.set(value, forKey: key)
    }
}
