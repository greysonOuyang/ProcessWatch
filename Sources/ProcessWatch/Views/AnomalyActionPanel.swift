import AppKit
import SwiftUI

struct AnomalyActionPanel: View {
  @EnvironmentObject private var model: AppModel

  let group: ProcessGroupSnapshot?

  @State private var alertState: ActionAlertState?

  var body: some View {
    DashboardCard(padding: 0, elevated: true) {
      if let group {
        ScrollView {
          VStack(alignment: .leading, spacing: 0) {
            panelHeader(group)
            separator
            anomalySummary(group)
            separator
            remediationActions(group)
            separator
            investigationActions(group)
            separator
            safetyNote
          }
        }
      } else {
        emptyState
      }
    }
    .alert(item: $alertState) { state in
      switch state {
      case .confirm(let action):
        return Alert(
          title: Text(action.title),
          message: Text(action.message(for: group)),
          primaryButton: .destructive(Text(action.confirmationTitle)) {
            guard let group else { return }
            perform(action, on: group)
          },
          secondaryButton: .cancel()
        )
      case .result(let message):
        return Alert(
          title: Text("操作结果"),
          message: Text(message),
          dismissButton: .default(Text("好"))
        )
      }
    }
  }

  private var emptyState: some View {
    VStack(spacing: 12) {
      Image(systemName: "cursorarrow.click.2")
        .font(.system(size: 34))
        .foregroundStyle(ProcessWatchTheme.textTertiary)
      Text("选择一个进程组")
        .font(.headline)
      Text("查看异常原因、进程身份和可执行操作。")
        .font(.caption)
        .foregroundStyle(ProcessWatchTheme.textSecondary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(30)
  }

  private func panelHeader(_ group: ProcessGroupSnapshot) -> some View {
    let color = severityColor(for: group)
    return VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 12) {
        ZStack {
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(color.opacity(0.15))
            .overlay(
              RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(color.opacity(0.22), lineWidth: 1)
            )
          Image(
            systemName: model.anomalyKinds(for: group).isEmpty
              ? "waveform.path.ecg" : "exclamationmark.triangle.fill"
          )
          .font(.title3)
          .foregroundStyle(color)
        }
        .frame(width: 42, height: 42)

        VStack(alignment: .leading, spacing: 5) {
          Text(panelTitle(for: group))
            .font(.headline)
          HStack(spacing: 6) {
            Text("\(group.name) × \(group.instanceCount)")
              .font(.callout.weight(.semibold))
            if let affiliation = group.affiliationSummary {
              StatusPill(text: affiliation, color: ProcessWatchTheme.amber)
            }
          }
        }
        Spacer(minLength: 0)
      }

      Text(group.path.isEmpty ? "可执行文件路径不可用" : group.path)
        .font(.system(.caption, design: .monospaced))
        .foregroundStyle(ProcessWatchTheme.textSecondary)
        .lineLimit(2)
        .truncationMode(.middle)
    }
    .padding(16)
    .background(
      LinearGradient(
        colors: [color.opacity(0.12), Color.clear],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    )
  }

  private func anomalySummary(_ group: ProcessGroupSnapshot) -> some View {
    let kinds = model.anomalyKinds(for: group)
    return VStack(alignment: .leading, spacing: 12) {
      Text(explanation(for: group, kinds: kinds))
        .font(.callout)
        .foregroundStyle(ProcessWatchTheme.textSecondary)
        .fixedSize(horizontal: false, vertical: true)

      HStack(spacing: 8) {
        MetricTile(
          title: "CPU 合计",
          value: formatPercent(group.cpuPercent),
          accent: group.cpuPercent >= model.settings.cpuThreshold
            ? ProcessWatchTheme.red : ProcessWatchTheme.amber
        )
        MetricTile(
          title: "占用内存",
          value: formatBytes(group.memoryBytes),
          accent: ProcessWatchTheme.amber,
          subtitle: "结束后由 macOS 回收"
        )
        MetricTile(
          title: "孤儿实例",
          value: "\(group.orphanCount)",
          accent: group.orphanCount > 0 ? ProcessWatchTheme.red : ProcessWatchTheme.teal
        )
      }

      HStack(spacing: 12) {
        Label("读取 \(formatRate(group.diskReadBytesPerSecond))", systemImage: "arrow.down.doc")
        Spacer()
        Label("写入 \(formatRate(group.diskWriteBytesPerSecond))", systemImage: "arrow.up.doc")
      }
      .font(.caption)
      .monospacedDigit()
      .foregroundStyle(ProcessWatchTheme.textSecondary)
    }
    .padding(16)
  }

  private func remediationActions(_ group: ProcessGroupSnapshot) -> some View {
    VStack(alignment: .leading, spacing: 9) {
      Text("释放资源")
        .font(.caption.weight(.semibold))
        .foregroundStyle(ProcessWatchTheme.textSecondary)

      if group.orphanCount > 0 {
        actionButton(
          title: "只结束孤儿进程",
          subtitle: "优先处理 PPID = 1 的 \(group.orphanCount) 个实例",
          systemImage: "link.badge.plus",
          color: ProcessWatchTheme.amber,
          prominent: true
        ) { alertState = .confirm(.orphans) }
      }

      actionButton(
        title: "只结束高占用实例",
        subtitle: "仅处理 CPU ≥ \(formatPercent(model.settings.cpuThreshold)) 的实例",
        systemImage: "flame",
        color: ProcessWatchTheme.amber,
        prominent: group.orphanCount == 0
      ) { alertState = .confirm(.highUsage) }

      actionButton(
        title: "优雅结束整个进程组",
        subtitle: "发送 SIGTERM，让进程有机会保存和清理",
        systemImage: "xmark.circle",
        color: ProcessWatchTheme.red
      ) { alertState = .confirm(.terminate) }

      actionButton(
        title: "强制退出整个进程组",
        subtitle: "发送 SIGKILL，仅在优雅结束无效时使用",
        systemImage: "bolt.trianglebadge.exclamationmark",
        color: ProcessWatchTheme.red
      ) { alertState = .confirm(.forceQuit) }
    }
    .padding(16)
  }

  private func investigationActions(_ group: ProcessGroupSnapshot) -> some View {
    VStack(alignment: .leading, spacing: 9) {
      Text("调查与抑制")
        .font(.caption.weight(.semibold))
        .foregroundStyle(ProcessWatchTheme.textSecondary)

      HStack(spacing: 8) {
        smallAction("忽略 1 小时", icon: "bell.slash") {
          model.settings.snooze(group, for: 3600)
          let message = "已暂停 \(group.name) 的异常提醒 1 小时。监控和采样仍会继续。"
          record(.snooze, group: group, outcome: .success, detail: message)
          showResult(message)
        }

        smallAction(
          model.settings.isIgnored(group) ? "移出白名单" : "加入白名单",
          icon: "checkmark.shield"
        ) {
          let message: String
          if model.settings.isIgnored(group) {
            model.settings.unignore(group)
            message = "已将 \(group.name) 移出白名单。"
          } else {
            model.settings.ignore(group)
            message = "已将 \(group.name) 加入白名单，后续不再生成异常提醒。"
          }
          record(.whitelist, group: group, outcome: .success, detail: message)
          showResult(message)
        }
      }

      HStack(spacing: 8) {
        smallAction("Finder", icon: "folder") {
          let success = ProcessActionService.reveal(group)
          let message = success ? "已在 Finder 中定位可执行文件。" : "无法读取可执行文件路径。"
          record(.reveal, group: group, outcome: success ? .success : .failed, detail: message)
          if !success { showResult(message) }
        }

        smallAction("复制命令", icon: "doc.on.doc") {
          let success = ProcessActionService.copyCommand(group)
          let message = success ? "已复制代表实例的完整命令。" : "没有可复制的命令。"
          record(.copyCommand, group: group, outcome: success ? .success : .failed, detail: message)
          showResult(message)
        }
      }

      smallAction("打开活动监视器", icon: "waveform.path.ecg") {
        let success = ProcessActionService.openActivityMonitor()
        let message = success ? "已打开活动监视器。" : "没有找到活动监视器。"
        record(.openActivityMonitor, group: group, outcome: success ? .success : .failed, detail: message)
        if !success { showResult(message) }
      }

      smallAction("运行自定义清理脚本…", icon: "terminal") {
        chooseCleanupScript(for: group)
      }
    }
    .padding(16)
  }

  private var safetyNote: some View {
    VStack(alignment: .leading, spacing: 6) {
      Label("关于“清理内存”", systemImage: "shield.lefthalf.filled")
        .font(.caption.weight(.semibold))
        .foregroundStyle(ProcessWatchTheme.teal)
      Text("macOS 没有安全、通用的一键清内存接口。结束确认异常的进程后，系统会自动回收其内存、CPU 时间片和文件句柄。自定义脚本由你选择并确认，ProcessWatch 不提升权限、不自动删除缓存。")
        .font(.caption2)
        .foregroundStyle(ProcessWatchTheme.textSecondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(16)
  }

  private var separator: some View {
    Rectangle()
      .fill(ProcessWatchTheme.border)
      .frame(height: 1)
  }

  private func actionButton(
    title: String,
    subtitle: String,
    systemImage: String,
    color: Color,
    prominent: Bool = false,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 11) {
        Image(systemName: systemImage)
          .frame(width: 20)
        VStack(alignment: .leading, spacing: 2) {
          Text(title).fontWeight(.semibold)
          Text(subtitle)
            .font(.caption2)
            .foregroundStyle(prominent ? Color.white.opacity(0.74) : ProcessWatchTheme.textSecondary)
        }
        Spacer()
        Image(systemName: "chevron.right")
          .font(.caption2.weight(.bold))
          .opacity(0.55)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        prominent ? color.opacity(0.62) : color.opacity(0.10),
        in: RoundedRectangle(cornerRadius: 9, style: .continuous)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 9, style: .continuous)
          .stroke(color.opacity(prominent ? 0.34 : 0.26), lineWidth: 1)
      )
      .foregroundStyle(prominent ? Color.white : color)
    }
    .buttonStyle(.plain)
  }

  private func smallAction(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Label(title, systemImage: icon)
        .font(.caption.weight(.medium))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
          ProcessWatchTheme.surfaceSoft,
          in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay(
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .stroke(ProcessWatchTheme.border, lineWidth: 1)
        )
    }
    .buttonStyle(.plain)
  }

  private func severityColor(for group: ProcessGroupSnapshot) -> Color {
    model.anomalyKinds(for: group).isEmpty ? ProcessWatchTheme.amber : ProcessWatchTheme.red
  }

  private func panelTitle(for group: ProcessGroupSnapshot) -> String {
    let kinds = model.anomalyKinds(for: group)
    if kinds.contains(.repoHarnessLeak) { return "repo-harness 疑似进程泄漏" }
    if kinds.contains(.processStorm) { return "检测到进程风暴" }
    if kinds.contains(.memoryGrowth) { return "内存持续增长" }
    if kinds.contains(.cpu) { return "CPU 持续高占用" }
    if kinds.contains(.diskWrite) { return "磁盘持续写入" }
    return "进程组操作"
  }

  private func explanation(for group: ProcessGroupSnapshot, kinds: Set<AnomalyKind>) -> String {
    if kinds.contains(.repoHarnessLeak) {
      return "该进程组包含 \(group.orphanCount) 个孤儿实例，并与 repo-harness 调用链相关。优先只结束孤儿进程，避免中断仍在使用的任务。"
    }
    if kinds.contains(.processStorm) {
      return "同一可执行文件存在 \(group.instanceCount) 个实例。持续增加通常意味着任务回收失败、重复启动或进程泄漏。"
    }
    if kinds.contains(.memoryGrowth) {
      return "检测到实例在观察窗口内持续增长内存。结束确认异常的进程后，macOS 会自动回收相关资源。"
    }
    if kinds.contains(.cpu) {
      return "该组中至少一个实例持续高 CPU。先检查完整命令和工作目录，再优雅结束异常实例。"
    }
    if kinds.contains(.diskWrite) {
      return "该组存在持续写盘行为。先定位工作目录，确认是否为日志、缓存或文件生成循环。"
    }
    return "当前未形成持续异常。你仍可检查命令、定位文件，或手动结束确认无用的实例。"
  }

  private func showResult(_ message: String) {
    DispatchQueue.main.async {
      alertState = .result(message)
    }
  }

  private func chooseCleanupScript(for group: ProcessGroupSnapshot) {
    let panel = NSOpenPanel()
    panel.title = "选择你信任的清理脚本"
    panel.message = "ProcessWatch 只启动你选择的脚本，不会自动删除缓存，也不会请求管理员权限。"
    panel.prompt = "选择并继续"
    panel.canChooseDirectories = false
    panel.canChooseFiles = true
    panel.allowsMultipleSelection = false
    guard panel.runModal() == .OK, let url = panel.url else { return }
    alertState = .confirm(.script(url))
  }

  private func perform(_ action: PendingGroupAction, on group: ProcessGroupSnapshot) {
    switch action {
    case .terminate:
      finish(ProcessActionService.terminate(group), action: .terminate, group: group)
    case .forceQuit:
      finish(ProcessActionService.forceQuit(group), action: .forceQuit, group: group)
    case .orphans:
      finish(ProcessActionService.terminateOrphans(group), action: .terminateOrphans, group: group)
    case .highUsage:
      finish(
        ProcessActionService.terminateHighUsage(group, cpuThreshold: model.settings.cpuThreshold),
        action: .terminateHighUsage,
        group: group
      )
    case .script(let url):
      let workingDirectory = group.representative?.workingDirectory
      switch ProcessActionService.launchCleanupScript(url, workingDirectory: workingDirectory) {
      case .success(let pid):
        let message = "已启动清理脚本（PID \(pid)）。ProcessWatch 不会自动提升权限或删除其他文件。"
        record(.cleanupScript, group: group, outcome: .success, detail: message)
        showResult(message)
      case .failure(let error):
        let message = "无法启动清理脚本：\(error.localizedDescription)"
        record(.cleanupScript, group: group, outcome: .failed, detail: message)
        showResult(message)
      }
    }
  }

  private func finish(
    _ report: ProcessActionReport,
    action: UserActionKind,
    group: ProcessGroupSnapshot
  ) {
    let outcome: UserActionOutcome
    if report.attempted == 0 || report.succeeded == 0 {
      outcome = .failed
    } else if report.failed > 0 {
      outcome = .partial
    } else {
      outcome = .success
    }
    record(
      action,
      group: group,
      outcome: outcome,
      detail: report.summary,
      attempted: report.attempted,
      succeeded: report.succeeded,
      failed: report.failed
    )
    showResult(report.summary)
  }

  private func record(
    _ action: UserActionKind,
    group: ProcessGroupSnapshot,
    outcome: UserActionOutcome,
    detail: String,
    attempted: Int = 0,
    succeeded: Int = 0,
    failed: Int = 0
  ) {
    model.actionHistory.add(
      UserActionRecord(
        processName: group.name,
        processPath: group.path,
        action: action,
        outcome: outcome,
        detail: detail,
        attempted: attempted,
        succeeded: succeeded,
        failed: failed
      )
    )
  }
}

private enum ActionAlertState: Identifiable {
  case confirm(PendingGroupAction)
  case result(String)

  var id: String {
    switch self {
    case .confirm(let action): return "confirm:\(action.id)"
    case .result(let message): return "result:\(message.hashValue)"
    }
  }
}

private enum PendingGroupAction: Identifiable {
  case terminate
  case forceQuit
  case orphans
  case highUsage
  case script(URL)

  var id: String {
    switch self {
    case .terminate: return "terminate"
    case .forceQuit: return "forceQuit"
    case .orphans: return "orphans"
    case .highUsage: return "highUsage"
    case .script(let url): return "script:\(url.path)"
    }
  }

  var title: String {
    switch self {
    case .terminate: return "优雅结束整个进程组？"
    case .forceQuit: return "强制退出整个进程组？"
    case .orphans: return "结束孤儿进程？"
    case .highUsage: return "结束高占用实例？"
    case .script: return "运行自定义清理脚本？"
    }
  }

  var confirmationTitle: String {
    switch self {
    case .forceQuit: return "强制退出"
    case .script: return "运行脚本"
    default: return "确认执行"
    }
  }

  func message(for group: ProcessGroupSnapshot?) -> String {
    guard let group else { return "没有选中的进程组。" }
    switch self {
    case .terminate:
      return "将向 \(group.instanceCount) 个可操作实例发送 SIGTERM。未保存的工作可能丢失。"
    case .forceQuit:
      return "将向 \(group.instanceCount) 个可操作实例发送 SIGKILL，进程没有机会保存数据或清理临时文件。"
    case .orphans:
      return "将只处理 \(group.orphanCount) 个 PPID = 1 的实例。请确认它们确实不再被任务使用。"
    case .highUsage:
      return "将只处理当前 CPU 超过阈值的实例。采样数据存在延迟，执行前请再次确认命令。"
    case .script(let url):
      return "将使用 /bin/zsh 启动：\n\(url.path)\n\n脚本由你提供，ProcessWatch 不检查或修改脚本内容。"
    }
  }
}
