import AppKit
import SwiftUI

struct MenuBarView: View {
  @EnvironmentObject private var model: AppModel

  var body: some View {
    ZStack {
      ProcessWatchTheme.popoverBackground
        .ignoresSafeArea()

      VStack(alignment: .leading, spacing: 12) {
        header
        metrics
        activeStatus
        topGroups
        footer
      }
      .padding(16)
    }
    .frame(width: 404)
    .preferredColorScheme(.dark)
  }

  private var header: some View {
    HStack(spacing: 10) {
      ZStack {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .fill(ProcessWatchTheme.amber.opacity(0.15))
          .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
              .stroke(ProcessWatchTheme.amber.opacity(0.20), lineWidth: 1)
          )
        Image(systemName: "waveform.path.ecg")
          .foregroundStyle(ProcessWatchTheme.amber)
      }
      .frame(width: 38, height: 38)

      VStack(alignment: .leading, spacing: 2) {
        Text("ProcessWatch")
          .font(.headline)
          .foregroundStyle(ProcessWatchTheme.textPrimary)
        HStack(spacing: 5) {
          Circle()
            .fill(model.isPaused ? ProcessWatchTheme.amber : ProcessWatchTheme.teal)
            .frame(width: 6, height: 6)
          Text(model.isPaused ? "监控已暂停" : "正在监控")
        }
        .font(.caption2)
        .foregroundStyle(ProcessWatchTheme.textSecondary)
      }

      Spacer()

      StatusPill(
        text: model.activeAnomalyCount > 0 ? "\(model.activeAnomalyCount) 个异常" : "稳定",
        color: model.activeAnomalyCount > 0 ? ProcessWatchTheme.red : ProcessWatchTheme.teal
      )
    }
  }

  private var metrics: some View {
    HStack(spacing: 8) {
      MetricTile(
        title: "CPU",
        value: formatPercent(model.system.cpuPercent),
        accent: cpuColor,
        subtitle: "系统占用"
      )
      MetricTile(
        title: "内存压力",
        value: model.system.memoryPressure.rawValue,
        accent: memoryColor,
        subtitle: formatPercent(model.system.memoryPercent)
      )
      MetricTile(
        title: "孤儿进程",
        value: "\(model.totalOrphanCount)",
        accent: model.totalOrphanCount > 0 ? ProcessWatchTheme.amber : ProcessWatchTheme.teal,
        subtitle: "\(model.processGroups.count) 个进程组"
      )
    }
  }

  @ViewBuilder
  private var activeStatus: some View {
    if let group = model.anomalousGroups.first {
      Button {
        WindowManager.shared.show(model: model, section: .alerts)
      } label: {
        DashboardCard(padding: 12, cornerRadius: 12, elevated: true) {
          HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
              .font(.title3)
              .foregroundStyle(ProcessWatchTheme.red)
              .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
              Text(primaryAnomalyTitle(for: group))
                .font(.callout.weight(.semibold))
                .foregroundStyle(ProcessWatchTheme.textPrimary)
              Text("\(group.name) × \(group.instanceCount) · CPU \(formatPercent(group.cpuPercent)) · 内存 \(formatBytes(group.memoryBytes))")
                .font(.caption)
                .foregroundStyle(ProcessWatchTheme.textSecondary)
                .lineLimit(2)
            }
            Spacer()
            Image(systemName: "chevron.right")
              .font(.caption.weight(.semibold))
              .foregroundStyle(ProcessWatchTheme.textTertiary)
          }
        }
      }
      .buttonStyle(.plain)
    } else {
      DashboardCard(padding: 12, cornerRadius: 12) {
        HStack(spacing: 10) {
          Image(systemName: "checkmark.shield.fill")
            .foregroundStyle(ProcessWatchTheme.teal)
          VStack(alignment: .leading, spacing: 2) {
            Text("未发现持续异常")
              .font(.callout.weight(.semibold))
            Text("瞬时峰值不会触发通知或写入历史")
              .font(.caption2)
              .foregroundStyle(ProcessWatchTheme.textSecondary)
          }
          Spacer()
        }
      }
    }
  }

  private var topGroups: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("高占用进程组")
          .font(.caption.weight(.semibold))
          .foregroundStyle(ProcessWatchTheme.textSecondary)
        Spacer()
        Text("CPU / 内存")
          .font(.caption2)
          .foregroundStyle(ProcessWatchTheme.textTertiary)
      }

      DashboardCard(padding: 0, cornerRadius: 12) {
        if model.topProcessGroups.isEmpty {
          Text("正在采集进程数据…")
            .font(.callout)
            .foregroundStyle(ProcessWatchTheme.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 70)
        } else {
          let visibleGroups = Array(model.topProcessGroups.prefix(4))
          VStack(spacing: 0) {
            ForEach(visibleGroups) { group in
              Button {
                model.selectedSection = .processes
                WindowManager.shared.show(model: model)
              } label: {
                HStack(spacing: 9) {
                  Image(
                    systemName: model.anomalyKinds(for: group).isEmpty
                      ? "terminal" : "exclamationmark.triangle.fill"
                  )
                  .frame(width: 17)
                  .foregroundStyle(
                    model.anomalyKinds(for: group).isEmpty
                      ? ProcessWatchTheme.teal : ProcessWatchTheme.red
                  )

                  VStack(alignment: .leading, spacing: 2) {
                    Text("\(group.name) × \(group.instanceCount)")
                      .font(.callout.weight(.medium))
                      .foregroundStyle(ProcessWatchTheme.textPrimary)
                      .lineLimit(1)
                    Text(group.orphanCount > 0 ? "孤儿 \(group.orphanCount) · 最长 \(formatCompactDuration(group.longestRuntime))" : "最长 \(formatCompactDuration(group.longestRuntime))")
                      .font(.caption2)
                      .foregroundStyle(ProcessWatchTheme.textTertiary)
                  }

                  Spacer()

                  Text(formatPercent(group.cpuPercent))
                    .monospacedDigit()
                    .foregroundStyle(
                      group.cpuPercent >= model.settings.cpuThreshold
                        ? ProcessWatchTheme.red : ProcessWatchTheme.amber
                    )
                  Text(formatBytes(group.memoryBytes))
                    .frame(width: 70, alignment: .trailing)
                    .monospacedDigit()
                    .foregroundStyle(ProcessWatchTheme.textSecondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .contentShape(Rectangle())
              }
              .buttonStyle(.plain)

              if group.id != visibleGroups.last?.id {
                Rectangle()
                  .fill(ProcessWatchTheme.border)
                  .frame(height: 1)
              }
            }
          }
        }
      }
    }
  }

  private var footer: some View {
    HStack(spacing: 8) {
      Button {
        model.togglePaused()
      } label: {
        Label(model.isPaused ? "继续" : "暂停", systemImage: model.isPaused ? "play.fill" : "pause.fill")
      }
      .buttonStyle(ProcessWatchButtonStyle(kind: .secondary))

      Button {
        WindowManager.shared.show(model: model, section: .overview)
      } label: {
        Label("打开主界面", systemImage: "macwindow")
      }
      .buttonStyle(ProcessWatchButtonStyle(kind: .primary))

      Spacer()

      Menu {
        Button("查看异常历史") {
          WindowManager.shared.show(model: model, section: .alerts)
        }
        Button("设置") {
          WindowManager.shared.show(model: model, section: .settings)
        }
        Divider()
        Button("退出 ProcessWatch", role: .destructive) {
          NSApplication.shared.terminate(nil)
        }
      } label: {
        Image(systemName: "ellipsis")
          .frame(width: 18)
      }
      .menuStyle(.borderlessButton)
      .buttonStyle(ProcessWatchButtonStyle(kind: .subtle))
      .frame(width: 42)
    }
  }

  private var cpuColor: Color {
    if model.system.cpuPercent >= model.settings.cpuThreshold { return ProcessWatchTheme.red }
    if model.system.cpuPercent >= model.settings.cpuThreshold * 0.65 { return ProcessWatchTheme.amber }
    return ProcessWatchTheme.teal
  }

  private var memoryColor: Color {
    switch model.system.memoryPressure {
    case .critical: return ProcessWatchTheme.red
    case .warning: return ProcessWatchTheme.amber
    default: return ProcessWatchTheme.teal
    }
  }

  private func primaryAnomalyTitle(for group: ProcessGroupSnapshot) -> String {
    let kinds = model.anomalyKinds(for: group)
    if kinds.contains(.repoHarnessLeak) { return "repo-harness 疑似进程泄漏" }
    if kinds.contains(.processStorm) { return "检测到进程风暴" }
    if kinds.contains(.memoryGrowth) { return "检测到内存持续增长" }
    if kinds.contains(.cpu) { return "检测到 CPU 持续高占用" }
    if kinds.contains(.diskWrite) { return "检测到持续写盘" }
    return "需要检查进程组"
  }
}
