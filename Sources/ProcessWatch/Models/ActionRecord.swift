import Foundation

enum UserActionKind: String, Codable, CaseIterable, Sendable {
  case terminate = "优雅结束"
  case forceQuit = "强制退出"
  case terminateOrphans = "结束孤儿进程"
  case terminateHighUsage = "结束高占用实例"
  case snooze = "临时忽略"
  case whitelist = "白名单变更"
  case reveal = "定位文件"
  case copyCommand = "复制命令"
  case openActivityMonitor = "打开活动监视器"
  case cleanupScript = "运行清理脚本"
}

enum UserActionOutcome: String, Codable, Sendable {
  case success = "成功"
  case partial = "部分成功"
  case failed = "失败"
  case informational = "已记录"
}

struct UserActionRecord: Identifiable, Codable, Hashable, Sendable {
  let id: UUID
  let date: Date
  let processName: String
  let processPath: String
  let action: UserActionKind
  let outcome: UserActionOutcome
  let detail: String
  let attempted: Int
  let succeeded: Int
  let failed: Int

  init(
    id: UUID = UUID(),
    date: Date = .now,
    processName: String,
    processPath: String,
    action: UserActionKind,
    outcome: UserActionOutcome,
    detail: String,
    attempted: Int = 0,
    succeeded: Int = 0,
    failed: Int = 0
  ) {
    self.id = id
    self.date = date
    self.processName = processName
    self.processPath = processPath
    self.action = action
    self.outcome = outcome
    self.detail = detail
    self.attempted = attempted
    self.succeeded = succeeded
    self.failed = failed
  }
}
