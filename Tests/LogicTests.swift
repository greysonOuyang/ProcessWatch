import Darwin
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
  affiliation: ProcessAffiliation = .none,
  userID: UInt32 = getuid(),
  effectiveUserID: UInt32 = getuid(),
  identityIsReliable: Bool = true,
  hasStartTime: Bool = true
) -> ProcessSnapshot {
  ProcessSnapshot(
    pid: pid,
    ppid: ppid,
    name: name,
    parentName: ppid == 1 ? "launchd" : "parent",
    path: path,
    commandLine: "\(path) worker",
    workingDirectory: "/tmp/project",
    startTime: hasStartTime ? sampledAt.addingTimeInterval(-600) : nil,
    userID: userID,
    effectiveUserID: effectiveUserID,
    identityIsReliable: identityIsReliable,
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
    try testActiveStateDuringNotificationCooldown()
    try testSnoozeAndWhitelist()
    try testDiagnosisScoring()
    try testLaunchdManagementDoesNotImplyLeak()
    try testProtectedProcessSafety()
    try testMixedProcessGroupActionability()
    try testIdentityRevalidation()
    try testRecoveryAssessment()
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
    try expect(group.launchdManagedCount == 1, "PPID 1 should count as launchd-managed")
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
  private static func testActiveStateDuringNotificationCooldown() throws {
    let suiteName = "ProcessWatch.CooldownTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let settings = SettingsStore(defaults: defaults)
    settings.cpuThreshold = 50
    settings.cpuDuration = 2
    settings.diskWriteMBps = 10_000
    settings.memoryGrowthMB = 10_000
    settings.processStormInstanceThreshold = 10_000

    let detector = AnomalyDetector()
    let start = Date(timeIntervalSince1970: 1_700_000_000)

    _ = detector.evaluate(
      processes: [process(pid: 250, cpu: 90, sampledAt: start)],
      settings: settings,
      now: start
    )
    let firstAlert = detector.evaluate(
      processes: [process(pid: 250, cpu: 90, sampledAt: start.addingTimeInterval(3))],
      settings: settings,
      now: start.addingTimeInterval(3)
    )
    try expect(firstAlert.events.contains { $0.kind == .cpu }, "First sustained CPU anomaly should alert")

    _ = detector.evaluate(
      processes: [process(pid: 250, cpu: 0, sampledAt: start.addingTimeInterval(4))],
      settings: settings,
      now: start.addingTimeInterval(4)
    )
    _ = detector.evaluate(
      processes: [process(pid: 250, cpu: 90, sampledAt: start.addingTimeInterval(5))],
      settings: settings,
      now: start.addingTimeInterval(5)
    )
    let recurrence = detector.evaluate(
      processes: [process(pid: 250, cpu: 90, sampledAt: start.addingTimeInterval(8))],
      settings: settings,
      now: start.addingTimeInterval(8)
    )

    try expect(recurrence.events.isEmpty, "Cooldown should suppress a duplicate notification")
    try expect(
      recurrence.active[250]?.contains(.cpu) == true,
      "A recurring CPU anomaly must remain active even while notification cooldown suppresses alerts"
    )
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

  @MainActor
  private static func testDiagnosisScoring() throws {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let suspicious = try ProcessGroupSnapshot.grouped([
      process(
        pid: 310,
        ppid: 1,
        cpu: 120,
        memory: 3 * 1_073_741_824,
        sampledAt: now,
        affiliation: .repoHarness
      ),
      process(pid: 311, cpu: 80, sampledAt: now, affiliation: .repoHarness),
    ]).first.unwrap("Expected suspicious group")

    let diagnosis = ProcessDiagnosisEngine.diagnose(
      group: suspicious,
      kinds: [.repoHarnessLeak, .processStorm, .cpu],
      thresholds: DiagnosisThresholds(
        cpuPercent: 80,
        diskWriteBytesPerSecond: 30 * 1_048_576,
        processStormInstances: 1
      )
    )
    try expect(diagnosis.score >= 70, "Leak, storm, and CPU evidence should be high suspicion")
    try expect(diagnosis.level == .high, "High diagnosis score should map to high suspicion")
    try expect(!diagnosis.evidence.isEmpty, "Diagnosis should explain its evidence")

    let normal = try ProcessGroupSnapshot.grouped([
      process(pid: 312, ppid: 1, cpu: 1, memory: 100, sampledAt: now)
    ]).first.unwrap("Expected normal group")
    let normalDiagnosis = ProcessDiagnosisEngine.diagnose(
      group: normal,
      kinds: [],
      thresholds: DiagnosisThresholds(
        cpuPercent: 80,
        diskWriteBytesPerSecond: 30 * 1_048_576,
        processStormInstances: 10
      )
    )
    try expect(normalDiagnosis.score < 20, "Low resource usage should not be marked suspicious")
    try expect(normal.launchdManagedCount == 1, "launchd-managed state should remain visible")
    try expect(
      !normalDiagnosis.evidence.contains { $0.localizedCaseInsensitiveContains("孤儿") },
      "PPID 1 must not be described as orphan evidence"
    )
  }

  @MainActor
  private static func testLaunchdManagementDoesNotImplyLeak() throws {
    let suiteName = "ProcessWatch.LaunchdTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let settings = SettingsStore(defaults: defaults)
    settings.processStormInstanceThreshold = 0
    settings.processStormDuration = 0
    settings.repoHarnessOrphanDuration = 0
    settings.cpuThreshold = 10_000
    settings.diskWriteMBps = 10_000
    settings.memoryGrowthMB = 10_000

    let detector = AnomalyDetector()
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let result = detector.evaluate(
      processes: [process(pid: 320, ppid: 1, sampledAt: now, affiliation: .repoHarness)],
      settings: settings,
      now: now
    )

    try expect(
      !result.events.contains { $0.kind == .repoHarnessLeak },
      "PPID 1 must not generate a repo-harness leak event"
    )
    try expect(
      result.activeGroups.values.allSatisfy { !$0.contains(.repoHarnessLeak) },
      "PPID 1 must not activate the repo-harness leak state"
    )
  }

  @MainActor
  private static func testProtectedProcessSafety() throws {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let systemProcess = process(
      pid: 99_991,
      name: "kernel_task",
      path: "/System/Library/kernel_task",
      sampledAt: now
    )
    try expect(!ProcessActionService.canTerminate(systemProcess), "Critical system process must be protected")
    try expect(
      ProcessActionService.protectionReason(for: systemProcess) != nil,
      "Protected process should expose a safety reason"
    )

    let rootProcess = process(pid: 99_992, sampledAt: now, userID: 0, effectiveUserID: 0)
    try expect(!ProcessActionService.canTerminate(rootProcess), "Root process must be blocked")

    let otherUserProcess = process(
      pid: 99_993,
      sampledAt: now,
      userID: getuid() &+ 1,
      effectiveUserID: getuid() &+ 1
    )
    try expect(!ProcessActionService.canTerminate(otherUserProcess), "Other-user process must be blocked")

    let missingPath = process(pid: 99_994, path: "", sampledAt: now)
    try expect(!ProcessActionService.canTerminate(missingPath), "Missing path must fail closed")

    let unreliable = process(pid: 99_995, sampledAt: now, identityIsReliable: false)
    try expect(!ProcessActionService.canTerminate(unreliable), "Unreliable identity must fail closed")

    let missingStart = process(pid: 99_996, sampledAt: now, hasStartTime: false)
    try expect(!ProcessActionService.canTerminate(missingStart), "Missing start time must fail closed")

    let userProcess = process(pid: 99_997, sampledAt: now)
    try expect(ProcessActionService.canTerminate(userProcess), "Ordinary current-user process should remain actionable")
  }

  @MainActor
  private static func testMixedProcessGroupActionability() throws {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let sharedPath = "/Users/test/bin/mixed-worker"
    let group = try ProcessGroupSnapshot.grouped([
      process(pid: 99_998, name: "mixed-worker", path: sharedPath, sampledAt: now),
      process(
        pid: 99_999,
        name: "mixed-worker",
        path: sharedPath,
        sampledAt: now,
        userID: 0,
        effectiveUserID: 0
      ),
    ]).first.unwrap("Expected mixed process group")

    try expect(group.instanceCount == 2, "Mixed group should keep both resource contributors")
    try expect(group.actionableProcessCount == 1, "Only the current-user process should be actionable")
    try expect(group.blockedProcessCount == 1, "The root process should remain blocked inside a mixed group")
  }

  @MainActor
  private static func testIdentityRevalidation() throws {
    let start = Date(timeIntervalSince1970: 1_700_000_000)
    let expected = ProcessIdentity(
      pid: 500,
      name: "bun",
      path: "/Users/test/.bun/bin/bun",
      startTime: start,
      userID: 501,
      effectiveUserID: 501,
      isReliable: true
    )
    let same = ProcessIdentity(
      pid: 500,
      name: "bun",
      path: "/Users/test/.bun/bin/bun",
      startTime: start,
      userID: 501,
      effectiveUserID: 501,
      isReliable: true
    )
    let reusedPID = ProcessIdentity(
      pid: 500,
      name: "bun",
      path: "/Users/test/.bun/bin/bun",
      startTime: start.addingTimeInterval(1),
      userID: 501,
      effectiveUserID: 501,
      isReliable: true
    )

    try expect(
      ProcessActionService.identitiesMatch(expected: expected, actual: same),
      "Identical process identities should match"
    )
    try expect(
      !ProcessActionService.identitiesMatch(expected: expected, actual: reusedPID),
      "Changed start time must block a reused PID"
    )
  }

  private static func testRecoveryAssessment() throws {
    let report = ProcessActionReport(
      title: "优雅结束",
      attempted: 2,
      succeeded: 2,
      failed: 0,
      details: [],
      attemptedPIDs: [400, 401],
      signaledPIDs: [400, 401]
    )
    let assessment = ProcessRecoveryAssessment(
      report: report,
      verifiedAt: Date(timeIntervalSince1970: 1_700_000_003),
      exitedPIDs: [400, 401],
      remainingPIDs: [],
      beforeGroupCPUPercent: 180,
      afterGroupCPUPercent: 0,
      beforeGroupMemoryBytes: 2_000_000_000,
      afterGroupMemoryBytes: 0,
      beforeSystemCPUPercent: 90,
      afterSystemCPUPercent: 25,
      beforeThermalState: .serious,
      afterThermalState: .fair
    )
    try expect(assessment.outcome == .success, "Confirmed exits should produce a successful outcome")
    try expect(assessment.summary.contains("已确认"), "Recovery summary should state verified process exit")
  }

  private static func testActionRecordEncoding() throws {
    let record = UserActionRecord(
      date: Date(timeIntervalSince1970: 1_700_000_000),
      processName: "bun",
      processPath: "/Users/test/.bun/bin/bun",
      action: .terminateHighUsage,
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

    try expect(decoded.action == .terminateHighUsage, "Action kind should round-trip")
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
