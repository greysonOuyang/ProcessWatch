import AppKit
import SwiftUI

struct AnomalyActionPanel: View {
  @EnvironmentObject private var model: AppModel

  let group: ProcessGroupSnapshot?

  @State private var alertState: ActionAlertState?
  @State private var isVerifying = false

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
            let diagnosis = model.diagnosis(for: group)
            if diagnosis.score >= 20 {
              StatusPill(text: "嫌疑 \(diagnosis.score)", color: severityColor(for: group))
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
    let diagnosis = model.diagnosis(for: group)
    return VStack(alignment: .leading, spacing: 12) {
      Text(diagnosis.summary)
        .font(.callout)
        .foregroundStyle(ProcessWatchTheme.textSecondary)
        .fixedSize(horizontal: false, vertical: true)

      VStack(alignment: .leading, spacing: 6) {
        ForEach(Array(diagnosis.evidence.prefix(4)), id: \.self) { item in
          Label(item, systemImage: "checkmark.circle")
            .font(.caption)
            .foregroundStyle(ProcessWatchTheme.textSecondary)
        }
        Label(diagnosis.recommendedAction, systemImage: "arrow.right.circle.fill")
          .font(.caption.weight(.medium))
          .foregroundStyle(ProcessWatchTheme.amber)
          .fixedSize(horizontal: false, vertical: true)
      }

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
          title: "可操作实例",
          value: "\(group.actionableProcessCount) / \(group.instanceCount)",
          accent: group.actionableProcessCount > 0 ? ProcessWatchTheme.teal : ProcessWatchTheme.textSecondary,
          subtitle: "\(group.launchdManagedCount) 个由 launchd 管理"
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
    let actionableCount = group.actionableProcessCount
    return VStack(alignment: .leading, spacing: 9) {
      HStack {
        Text("安全操作")
          .font(.caption.weight(.semibold))
          .foregroundStyle(ProcessWatchTheme.textSecondary)
        Spacer()
        if isVerifying {
          ProgressView()
            .controlSize(.small)
          Text("正在确认退出与资源变化")
            .font(.caption2)
            .foregroundStyle(ProcessWatchTheme.textSecondary)
        }
      }

      if actionableCount == 0 {
        Label(
          "该组没有通过所有者、路径和启动身份校验的可操作进程。ProcessWatch 不会向这些实例发送信号。",
          systemImage: "lock.shield"
        )
        .font(.caption)
        .foregroundStyle(ProcessWatchTheme.amber)
        .fixedSize(horizontal: false, vertical: true)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
          ProcessWatchTheme.amber.opacity(0.09),
          in: RoundedRectangle(cornerRadius: 9, style: .continuous)
        )
      } else {
        if group.blockedProcessCount > 0 {
          Text("仅 \(actionableCount) / \(group.instanceCount) 个实例属于当前用户且身份完整；其余实例会被自动跳过。")
            .font(.caption2)
            .foregroundStyle(ProcessWatchTheme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }

        actionButton(
          title: "只结束高占用实例",
          subtitle: "仅处理 CPU ≥ \(formatPercent(model.settings.cpuThreshold)) 且通过安全校验的实例",
          systemImage: "flame",
          color: ProcessWatchTheme.amber,
          prominent: true
        ) { alertState = .confirm(.highUsage) }

        actionButton(
          title: "优雅结束可操作实例",
          subtitle: "向通过身份校验的当前用户进程发送 SIGTERM",
          systemImage: "xmark.circle",
          color: ProcessWatchTheme.red
        ) { alertState = .confirm(.terminate) }

        actionButton(
          title: "强制退出可操作实例",
          subtitle: "发送 SIGKILL，仅在优雅结束无效时使用",
          systemImage: "bolt.trianglebadge.exclamationmark",
          color: ProcessWatchTheme.red
        ) { alertState = .confirm(.forceQuit) }
      }
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
      Text("macOS 没有安全、通用的一键清内存接口。ProcessWatch 只允许操作身份完整且属于当前用户的进程，并会在发送信号前重新校验 PID、路径、所有者和启动时间。自定义脚本由你选择并确认，ProcessWatch 不提升权限、不自动删除缓存。")
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
    .disabled(isVerifying)
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
      return "该进程组满足 repo-harness 专用生命周期规则。操作前仍需核对完整命令，并且只处理通过身份校验的当前用户进程。"
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
    guard report.attempted > 0, report.succeeded > 0 else {
      record(action, group: group, outcome: .failed, detail: report.summary)
      showResult(report.summary)
      return
    }

    isVerifying = true
    Task { @MainActor in
      let assessment = await model.verifyProcessAction(report, originalGroup: group)
      isVerifying = false
      record(
        action,
        group: group,
        outcome: assessment.outcome,
        detail: assessment.summary,
        attempted: report.attempted,
        succeeded: assessment.exitedPIDs.count,
        failed: report.failed + assessment.remainingPIDs.count
      )
      showResult(assessment.summary)
    }
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
  case highUsage
  case script(URL)

  var id: String {
    switch self {
    case .terminate: return "terminate"
    case .forceQuit: return "forceQuit"
    case .highUsage: return "highUsage"
    case .script(let url): return "script:\(url.path)"
    }
  }

  var title: String {
    switch self {
    case .terminate: return "优雅结束可操作实例？"
    case .forceQuit: return "强制退出可操作实例？"
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
      return "将向 \(group.actionableProcessCount) 个通过安全校验的实例发送 SIGTERM。发送前会再次核对身份；未保存的工作可能丢失。"
    case .forceQuit:
      return "将向 \(group.actionableProcessCount) 个通过安全校验的实例发送 SIGKILL，进程没有机会保存数据或清理临时文件。"
    case .highUsage:
      return "将只处理当前 CPU 超过阈值的实例。采样数据存在延迟，执行前请再次确认命令。"
    case .script(let url):
      return "将使用 /bin/zsh 启动：\n\(url.path)\n\n脚本由你提供，ProcessWatch 不检查或修改脚本内容。"
    }
  }
}
