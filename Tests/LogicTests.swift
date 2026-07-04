import Foundation

private enum TestFailure: Error, CustomStringConvertible {
  case assertion(String)

  var description: String {
    switch self {
    case .assertion(let message): return message
    }
  }
}

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
  guard condition() else { throw TestFailure.assertion(message) }
}

private func process(
  pid: Int32,
  ppid: Int32 = 2,
  name: String = "bun",
  path: String = "/Users/test/.bun/bin/bun",
  cpu: Double = 0,
  memory: UInt64 = 0,
  sampledAt: Date,
  affiliation: ProcessAffiliation = .none
) -> ProcessSnapshot {
  ProcessSnapshot(
    pid: pid,
    ppid: ppid,
    name: name,
    parentName: ppid == 1 ? "launchd" : "parent",
    path: path,
    commandLine: "\(path) worker",
    workingDirectory: "/tmp/project",
    startTime: sampledAt.addingTimeInterval(-600),
    affiliation: affiliation,
    cpuPercent: cpu,
    memoryBytes: memory,
    diskReadBytesPerSecond: 0,
    diskWriteBytesPerSecond: 0,
    sampledAt: sampledAt
  )
}

@main
struct LogicTests {
  @MainActor
  static func main() throws {
    try testGrouping()
    try testProcessStormState()
    try testSnoozeAndWhitelist()
    try testActionRecordEncoding()
    print("✓ ProcessWatch logic tests passed")
  }

  @MainActor
  private static func testGrouping() throws {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let group = try ProcessGroupSnapshot.grouped([
      process(pid: 100, ppid: 1, cpu: 30, memory: 300, sampledAt: now),
      process(pid: 101, ppid: 9, cpu: 70, memory: 700, sampledAt: now),
    ]).first.unwrap("Expected one group")

    try expect(group.instanceCount == 2, "Group instance count should be 2")
    try expect(group.cpuPercent == 100, "CPU should aggregate across instances")
    try expect(group.memoryBytes == 1_000, "Memory should aggregate across instances")
    try expect(group.orphanCount == 1, "PPID 1 should count as orphan")
  }

  @MainActor
  private static func testProcessStormState() throws {
    let suiteName = "ProcessWatch.LogicTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let settings = SettingsStore(defaults: defaults)
    settings.processStormInstanceThreshold = 1
    settings.processStormDuration = 2
    settings.repoHarnessOrphanDuration = 10_000
    settings.cpuThreshold = 10_000
    settings.diskWriteMBps = 10_000
    settings.memoryGrowthMB = 10_000

    let detector = AnomalyDetector()
    let start = Date(timeIntervalSince1970: 1_700_000_000)
    let samples = [
      process(pid: 200, sampledAt: start),
      process(pid: 201, sampledAt: start),
    ]

    let initial = detector.evaluate(processes: samples, settings: settings, now: start)
    try expect(initial.events.isEmpty, "Storm should not alert immediately")

    let laterSamples = samples.map { sample in
      process(
        pid: sample.pid,
        ppid: sample.ppid,
        name: sample.name,
        path: sample.path,
        cpu: sample.cpuPercent,
        memory: sample.memoryBytes,
        sampledAt: start.addingTimeInterval(3)
      )
    }
    let later = detector.evaluate(
      processes: laterSamples,
      settings: settings,
      now: start.addingTimeInterval(3)
    )
    try expect(
      later.events.contains { $0.kind == .processStorm }, "Storm should alert after duration")
    try expect(!later.activeGroups.isEmpty, "Storm group should remain active")
  }
  @MainActor
  private static func testSnoozeAndWhitelist() throws {
    let suiteName = "ProcessWatch.SettingsTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let settings = SettingsStore(defaults: defaults)
    settings.snooze("bun", for: 3600)
    try expect(settings.isSnoozed("bun"), "Snoozed process should be suppressed")
    try expect(settings.isSuppressed("bun"), "Snoozed process should be suppressed by detector")
    settings.clearSnooze("bun")
    try expect(!settings.isSnoozed("bun"), "Cleared snooze should no longer be active")

    settings.ignore("bun")
    try expect(settings.isIgnored("bun"), "Whitelisted process should be persisted")
    settings.unignore("bun")
    try expect(!settings.isIgnored("bun"), "Removed whitelist entry should no longer be ignored")
  }

  private static func testActionRecordEncoding() throws {
    let record = UserActionRecord(
      date: Date(timeIntervalSince1970: 1_700_000_000),
      processName: "bun",
      processPath: "/Users/test/.bun/bin/bun",
      action: .terminateOrphans,
      outcome: .partial,
      detail: "成功 2 个，失败 1 个",
      attempted: 3,
      succeeded: 2,
      failed: 1
    )

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(record)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode(UserActionRecord.self, from: data)

    try expect(decoded.action == .terminateOrphans, "Action kind should round-trip")
    try expect(decoded.outcome == .partial, "Action outcome should round-trip")
    try expect(decoded.failed == 1, "Action counts should round-trip")
  }

}

extension Optional {
  fileprivate func unwrap(_ message: String) throws -> Wrapped {
    guard let value = self else { throw TestFailure.assertion(message) }
    return value
  }
}
