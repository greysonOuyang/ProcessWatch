import AppKit
import Darwin
import Foundation
#if canImport(ProcessWatchC)
import ProcessWatchC
#endif

struct ProcessActionReport: Sendable {
  let title: String
  let attempted: Int
  let succeeded: Int
  let failed: Int
  let details: [String]
  let attemptedPIDs: [Int32]
  let signaledPIDs: [Int32]
  let blockedPIDs: [Int32]

  init(
    title: String,
    attempted: Int,
    succeeded: Int,
    failed: Int,
    details: [String],
    attemptedPIDs: [Int32] = [],
    signaledPIDs: [Int32] = [],
    blockedPIDs: [Int32] = []
  ) {
    self.title = title
    self.attempted = attempted
    self.succeeded = succeeded
    self.failed = failed
    self.details = details
    self.attemptedPIDs = attemptedPIDs
    self.signaledPIDs = signaledPIDs
    self.blockedPIDs = blockedPIDs
  }

  var summary: String {
    if attempted == 0 {
      return details.first ?? "没有可操作的进程。"
    }
    if failed == 0 {
      return "\(title)请求已发送：\(succeeded) 个进程正在等待复查。"
    }
    return
      "\(title)请求已发送：成功发送 \(succeeded) 个，发送失败 \(failed) 个。\n\(details.prefix(5).joined(separator: "\n"))"
  }
}

struct ProcessRecoveryAssessment: Sendable {
  let report: ProcessActionReport
  let verifiedAt: Date
  let exitedPIDs: [Int32]
  let remainingPIDs: [Int32]
  let beforeGroupCPUPercent: Double
  let afterGroupCPUPercent: Double
  let beforeGroupMemoryBytes: UInt64
  let afterGroupMemoryBytes: UInt64
  let beforeSystemCPUPercent: Double
  let afterSystemCPUPercent: Double
  let beforeThermalState: ThermalState
  let afterThermalState: ThermalState

  var outcome: UserActionOutcome {
    if report.attempted == 0 || report.succeeded == 0 { return .failed }
    if report.failed > 0 || !remainingPIDs.isEmpty { return .partial }
    return .success
  }

  var summary: String {
    guard report.attempted > 0 else { return report.summary }

    var lines: [String] = []
    if remainingPIDs.isEmpty {
      lines.append("已确认 \(exitedPIDs.count) 个目标进程退出。")
    } else {
      lines.append(
        "已确认退出 \(exitedPIDs.count) 个；仍在运行 \(remainingPIDs.count) 个（PID \(remainingPIDs.map(String.init).joined(separator: ", "))）。"
      )
    }

    let released = beforeGroupMemoryBytes >= afterGroupMemoryBytes
      ? beforeGroupMemoryBytes - afterGroupMemoryBytes : 0
    lines.append(
      "进程组 CPU：\(formatPercent(beforeGroupCPUPercent)) → \(formatPercent(afterGroupCPUPercent))；内存：\(formatBytes(beforeGroupMemoryBytes)) → \(formatBytes(afterGroupMemoryBytes))。"
    )
    if released > 0 {
      lines.append("已观察到约 \(formatBytes(released)) 的进程内存不再占用。")
    }
    lines.append(
      "系统 CPU：\(formatPercent(beforeSystemCPUPercent)) → \(formatPercent(afterSystemCPUPercent))；热状态：\(beforeThermalState.rawValue) → \(afterThermalState.rawValue)。"
    )

    if !remainingPIDs.isEmpty {
      lines.append("优雅结束可能仍在清理；确认无未保存工作后，再考虑强制退出剩余实例。")
    } else if afterSystemCPUPercent >= beforeSystemCPUPercent && beforeGroupCPUPercent > 0 {
      lines.append("目标进程已退出，但系统负载尚未下降，可能还有其他高占用进程。")
    }
    return lines.joined(separator: "\n")
  }
}

@MainActor
enum ProcessActionService {
  @discardableResult
  static func reveal(_ process: ProcessSnapshot) -> Bool {
    guard !process.path.isEmpty else { return false }
    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: process.path)])
    return true
  }

  @discardableResult
  static func reveal(_ group: ProcessGroupSnapshot) -> Bool {
    guard let representative = group.representative else { return false }
    return reveal(representative)
  }

  @discardableResult
  static func openWorkingDirectory(_ process: ProcessSnapshot) -> Bool {
    guard !process.workingDirectory.isEmpty else { return false }
    return NSWorkspace.shared.open(URL(fileURLWithPath: process.workingDirectory, isDirectory: true))
  }

  @discardableResult
  static func copyCommand(_ process: ProcessSnapshot) -> Bool {
    let command = process.commandLine.isEmpty ? process.path : process.commandLine
    guard !command.isEmpty else { return false }
    NSPasteboard.general.clearContents()
    return NSPasteboard.general.setString(command, forType: .string)
  }

  @discardableResult
  static func copyCommand(_ group: ProcessGroupSnapshot) -> Bool {
    guard let representative = group.representative else { return false }
    return copyCommand(representative)
  }

  @discardableResult
  static func openActivityMonitor() -> Bool {
    let candidates = [
      "/System/Applications/Utilities/Activity Monitor.app",
      "/Applications/Utilities/Activity Monitor.app",
    ]
    for path in candidates where FileManager.default.fileExists(atPath: path) {
      let configuration = NSWorkspace.OpenConfiguration()
      NSWorkspace.shared.openApplication(
        at: URL(fileURLWithPath: path),
        configuration: configuration
      ) { _, _ in }
      return true
    }
    return false
  }

  static func canTerminate(_ process: ProcessSnapshot) -> Bool {
    process.safetyAssessment.canTerminate
  }

  static func protectionReason(for process: ProcessSnapshot) -> String? {
    let assessment = process.safetyAssessment
    return assessment.canTerminate ? nil : assessment.reason
  }

  static func identitiesMatch(expected: ProcessIdentity, actual: ProcessIdentity) -> Bool {
    ProcessSafetyPolicy.identitiesMatch(expected: expected, actual: actual)
  }

  static func isProcessRunning(pid: Int32) -> Bool {
    guard pid > 0 else { return false }
    if kill(pid, 0) == 0 { return true }
    return errno == EPERM
  }

  @discardableResult
  static func terminate(_ process: ProcessSnapshot) -> Bool {
    send(signal: SIGTERM, to: process)
  }

  @discardableResult
  static func forceQuit(_ process: ProcessSnapshot) -> Bool {
    send(signal: SIGKILL, to: process)
  }

  static func terminate(_ group: ProcessGroupSnapshot) -> ProcessActionReport {
    perform(title: "优雅结束", signal: SIGTERM, processes: group.processes)
  }

  static func forceQuit(_ group: ProcessGroupSnapshot) -> ProcessActionReport {
    perform(title: "强制退出", signal: SIGKILL, processes: group.processes)
  }

  static func terminateHighUsage(_ group: ProcessGroupSnapshot, cpuThreshold: Double)
    -> ProcessActionReport
  {
    let threshold = max(10, cpuThreshold)
    let candidates = group.processes.filter { $0.cpuPercent >= threshold }
    return perform(title: "结束高占用实例", signal: SIGTERM, processes: candidates)
  }

  static func launchCleanupScript(_ url: URL, workingDirectory: String?) -> Result<Int32, Error> {
    do {
      let process = Process()
      process.executableURL = URL(fileURLWithPath: "/bin/zsh")
      process.arguments = [url.path]
      if let workingDirectory, !workingDirectory.isEmpty {
        process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory, isDirectory: true)
      }
      process.standardOutput = FileHandle.nullDevice
      process.standardError = FileHandle.nullDevice
      try process.run()
      return .success(process.processIdentifier)
    } catch {
      return .failure(error)
    }
  }

  private enum SignalAttempt {
    case signaled
    case blocked(String)
    case failed(String)
  }

  private static func send(signal: Int32, to process: ProcessSnapshot) -> Bool {
    if case .signaled = attemptSignal(signal, to: process) {
      return true
    }
    return false
  }

  private static func perform(title: String, signal: Int32, processes: [ProcessSnapshot])
    -> ProcessActionReport
  {
    let unique = Dictionary(grouping: processes, by: \.pid)
      .compactMap { $0.value.first }
      .sorted { $0.pid < $1.pid }

    var details: [String] = []
    var attemptedPIDs: [Int32] = []
    var signaledPIDs: [Int32] = []
    var blockedPIDs: [Int32] = []

    for process in unique {
      switch attemptSignal(signal, to: process) {
      case .signaled:
        attemptedPIDs.append(process.pid)
        signaledPIDs.append(process.pid)
      case .blocked(let reason):
        blockedPIDs.append(process.pid)
        details.append("PID \(process.pid) 未操作：\(reason)")
      case .failed(let reason):
        attemptedPIDs.append(process.pid)
        details.append("PID \(process.pid)：\(reason)")
      }
    }

    if unique.isEmpty {
      details = ["没有符合本次操作条件的进程。"]
    } else if attemptedPIDs.isEmpty && details.isEmpty {
      details = ["没有通过安全校验的进程。"]
    }

    return ProcessActionReport(
      title: title,
      attempted: attemptedPIDs.count,
      succeeded: signaledPIDs.count,
      failed: attemptedPIDs.count - signaledPIDs.count,
      details: details,
      attemptedPIDs: attemptedPIDs,
      signaledPIDs: signaledPIDs,
      blockedPIDs: blockedPIDs
    )
  }

  private static func attemptSignal(_ signal: Int32, to process: ProcessSnapshot) -> SignalAttempt {
    let assessment = process.safetyAssessment
    guard assessment.canTerminate else {
      return .blocked(assessment.reason)
    }
    guard let currentIdentity = readCurrentIdentity(pid: process.pid) else {
      return .blocked("执行前无法重新读取进程身份")
    }
    guard identitiesMatch(expected: process.identity, actual: currentIdentity) else {
      return .blocked("进程身份已变化，可能已退出或 PID 已被复用")
    }

    if kill(process.pid, signal) == 0 {
      return .signaled
    }
    return .failed(lastPOSIXErrorMessage())
  }

  private static func readCurrentIdentity(pid: Int32) -> ProcessIdentity? {
    #if canImport(ProcessWatchC)
    var raw = PWProcessSample()
    guard pw_read_process(pid, &raw) else { return nil }

    let startSeconds = pw_process_sample_start_time_sec(&raw)
    let startMicroseconds = pw_process_sample_start_time_usec(&raw)
    let startTime: Date?
    if startSeconds > 0 {
      startTime = Date(
        timeIntervalSince1970: TimeInterval(startSeconds)
          + TimeInterval(startMicroseconds) / 1_000_000
      )
    } else {
      startTime = nil
    }

    return ProcessIdentity(
      pid: pid,
      name: decodedCString(pw_process_sample_name(&raw)),
      path: decodedCString(pw_process_sample_path(&raw)),
      startTime: startTime,
      userID: pw_process_sample_user_id(&raw),
      effectiveUserID: pw_process_sample_effective_user_id(&raw),
      isReliable: pw_process_sample_identity_reliable(&raw)
    )
    #else
    return nil
    #endif
  }

  private static func decodedCString(_ pointer: UnsafePointer<CChar>?) -> String {
    guard let pointer else { return "" }
    return String(cString: pointer)
  }

  private static func lastPOSIXErrorMessage() -> String {
    let code = errno
    guard let pointer = strerror(code) else { return "POSIX error \(code)" }
    return String(cString: pointer)
  }
}
