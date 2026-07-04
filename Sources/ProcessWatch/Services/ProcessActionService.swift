import AppKit
import Darwin
import Foundation

struct ProcessActionReport: Sendable {
  let title: String
  let attempted: Int
  let succeeded: Int
  let failed: Int
  let details: [String]

  var summary: String {
    if attempted == 0 {
      return details.first ?? "没有可操作的进程。"
    }
    if failed == 0 {
      return "\(title)完成：成功处理 \(succeeded) 个进程。"
    }
    return
      "\(title)完成：成功 \(succeeded) 个，失败 \(failed) 个。\n\(details.prefix(5).joined(separator: "\n"))"
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
    process.pid > 1 && process.pid != getpid()
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

  static func terminateOrphans(_ group: ProcessGroupSnapshot) -> ProcessActionReport {
    perform(title: "结束孤儿进程", signal: SIGTERM, processes: group.processes.filter(\.isOrphan))
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

  private static func send(signal: Int32, to process: ProcessSnapshot) -> Bool {
    guard canTerminate(process) else { return false }
    return kill(process.pid, signal) == 0
  }

  private static func perform(title: String, signal: Int32, processes: [ProcessSnapshot])
    -> ProcessActionReport
  {
    let unique = Dictionary(grouping: processes, by: \.pid).compactMap { $0.value.first }
    let controllable = unique.filter(canTerminate).sorted { lhs, rhs in
      if lhs.isOrphan != rhs.isOrphan { return lhs.isOrphan }
      return lhs.runtime < rhs.runtime
    }

    guard !controllable.isEmpty else {
      return ProcessActionReport(
        title: title,
        attempted: 0,
        succeeded: 0,
        failed: 0,
        details: ["没有可操作的进程；系统进程、PID 1 和 ProcessWatch 自身会被自动排除。"]
      )
    }

    var succeeded = 0
    var details: [String] = []
    for process in controllable {
      if kill(process.pid, signal) == 0 {
        succeeded += 1
      } else {
        let errorMessage: String
        if let pointer = strerror(errno) {
          errorMessage = String(cString: pointer)
        } else {
          errorMessage = "unknown error"
        }
        details.append("PID \(process.pid)：\(errorMessage)")
      }
    }
    return ProcessActionReport(
      title: title,
      attempted: controllable.count,
      succeeded: succeeded,
      failed: controllable.count - succeeded,
      details: details
    )
  }
}
