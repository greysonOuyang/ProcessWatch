import Combine
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
    static let snoozedProcessNames = "snoozedProcessNames"
  }

  private let defaults: UserDefaults
  private var isLoading = true

  @Published var cpuThreshold: Double { didSet { save(Key.cpuThreshold, cpuThreshold) } }
  @Published var cpuDuration: TimeInterval { didSet { save(Key.cpuDuration, cpuDuration) } }
  @Published var memoryGrowthMB: Double { didSet { save(Key.memoryGrowthMB, memoryGrowthMB) } }
  @Published var memoryWindow: TimeInterval { didSet { save(Key.memoryWindow, memoryWindow) } }
  @Published var diskWriteMBps: Double { didSet { save(Key.diskWriteMBps, diskWriteMBps) } }
  @Published var diskDuration: TimeInterval { didSet { save(Key.diskDuration, diskDuration) } }
  @Published var processStormInstanceThreshold: Double {
    didSet { save(Key.processStormInstanceThreshold, processStormInstanceThreshold) }
  }
  @Published var processStormDuration: TimeInterval {
    didSet { save(Key.processStormDuration, processStormDuration) }
  }
  @Published var repoHarnessOrphanDuration: TimeInterval {
    didSet { save(Key.repoHarnessOrphanDuration, repoHarnessOrphanDuration) }
  }
  @Published var samplingInterval: TimeInterval {
    didSet { save(Key.samplingInterval, samplingInterval) }
  }
  @Published var notificationsEnabled: Bool {
    didSet { save(Key.notificationsEnabled, notificationsEnabled) }
  }
  @Published private(set) var ignoredProcessNames: Set<String>
  @Published private(set) var snoozedUntil: [String: Date]

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
      Key.notificationsEnabled: true,
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
    if let data = defaults.data(forKey: Key.snoozedProcessNames),
      let stored = try? JSONDecoder().decode([String: Date].self, from: data)
    {
      snoozedUntil = stored.filter { $0.value > Date() }
    } else {
      snoozedUntil = [:]
    }
    isLoading = false
    persistSnoozes()
  }

  func ignore(_ processName: String) {
    ignoreKey("name:\(processName.lowercased())")
  }

  func ignore(_ group: ProcessGroupSnapshot) {
    ignoreKey(group.id)
  }

  func unignore(_ processName: String) {
    ignoredProcessNames.remove(processName)
    ignoredProcessNames.remove("name:\(processName.lowercased())")
    persistIgnoredNames()
  }

  func unignore(_ group: ProcessGroupSnapshot) {
    ignoredProcessNames.remove(group.id)
    persistIgnoredNames()
  }

  func unignoreKey(_ key: String) {
    ignoredProcessNames.remove(key)
    persistIgnoredNames()
  }

  func isIgnored(_ processName: String) -> Bool {
    ignoredProcessNames.contains(processName)
      || ignoredProcessNames.contains("name:\(processName.lowercased())")
  }

  func isIgnored(_ group: ProcessGroupSnapshot) -> Bool {
    ignoredProcessNames.contains(group.id) || isIgnored(group.name)
  }

  func snooze(_ processName: String, for duration: TimeInterval) {
    snoozeKey("name:\(processName.lowercased())", for: duration)
  }

  func snooze(_ group: ProcessGroupSnapshot, for duration: TimeInterval) {
    snoozeKey(group.id, for: duration)
  }

  func clearSnooze(_ processName: String) {
    snoozedUntil.removeValue(forKey: processName)
    snoozedUntil.removeValue(forKey: "name:\(processName.lowercased())")
    persistSnoozes()
  }

  func clearSnoozeKey(_ key: String) {
    snoozedUntil.removeValue(forKey: key)
    persistSnoozes()
  }

  func isSnoozed(_ processName: String, now: Date = .now) -> Bool {
    isSnoozedKey(processName, now: now)
      || isSnoozedKey("name:\(processName.lowercased())", now: now)
  }

  func isSnoozed(_ group: ProcessGroupSnapshot, now: Date = .now) -> Bool {
    isSnoozedKey(group.id, now: now) || isSnoozed(group.name, now: now)
  }

  func isSuppressed(_ process: ProcessSnapshot, now: Date = .now) -> Bool {
    ignoredProcessNames.contains(process.executableGroupKey) || isIgnored(process.name)
      || isSnoozedKey(process.executableGroupKey, now: now) || isSnoozed(process.name, now: now)
  }

  func isSuppressed(_ group: ProcessGroupSnapshot, now: Date = .now) -> Bool {
    isIgnored(group) || isSnoozed(group, now: now)
  }

  func isSuppressed(_ processName: String, now: Date = .now) -> Bool {
    isIgnored(processName) || isSnoozed(processName, now: now)
  }

  func displayName(forSuppressionKey key: String) -> String {
    if key.hasPrefix("path:") { return String(key.dropFirst(5)) }
    if key.hasPrefix("name:") { return String(key.dropFirst(5)) }
    return key
  }

  private func ignoreKey(_ key: String) {
    guard !key.isEmpty else { return }
    ignoredProcessNames.insert(key)
    persistIgnoredNames()
  }

  private func snoozeKey(_ key: String, for duration: TimeInterval) {
    guard !key.isEmpty else { return }
    snoozedUntil[key] = Date().addingTimeInterval(max(60, duration))
    persistSnoozes()
  }

  private func isSnoozedKey(_ key: String, now: Date) -> Bool {
    guard let date = snoozedUntil[key] else { return false }
    return date > now
  }

  private func persistIgnoredNames() {
    defaults.set(ignoredProcessNames.sorted(), forKey: Key.ignoredProcessNames)
    objectWillChange.send()
  }

  private func persistSnoozes() {
    if let data = try? JSONEncoder().encode(snoozedUntil) {
      defaults.set(data, forKey: Key.snoozedProcessNames)
    }
    objectWillChange.send()
  }

  private func save(_ key: String, _ value: Any) {
    guard !isLoading else { return }
    defaults.set(value, forKey: key)
  }
}
