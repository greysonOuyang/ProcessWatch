import AppKit
import SwiftUI

struct SettingsView: View {
  private struct SnoozeEntry: Identifiable {
    let key: String
    let deadline: Date
    var id: String { key }
  }

  @ObservedObject var settings: SettingsStore
  @ObservedObject var loginItem: LoginItemService

  private let columns = [
    GridItem(.flexible(), spacing: ProcessWatchLayout.cardGap),
    GridItem(.flexible(), spacing: ProcessWatchLayout.cardGap),
  ]

  private var activeSnoozes: [SnoozeEntry] {
    settings.snoozedUntil
      .filter { $0.value > Date() }
      .map { SnoozeEntry(key: $0.key, deadline: $0.value) }
      .sorted { $0.deadline < $1.deadline }
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: ProcessWatchLayout.sectionGap) {
        HStack {
          SectionHeading(
            title: "设置",
            subtitle: "调整持续异常规则、通知、白名单和应用行为"
          )
          Spacer()
          StatusPill(text: "本地优先", color: ProcessWatchTheme.teal)
        }

        generalCard

        LazyVGrid(columns: columns, spacing: ProcessWatchLayout.cardGap) {
          cpuCard
          memoryCard
          diskCard
          stormCard
        }

        LazyVGrid(columns: columns, spacing: ProcessWatchLayout.cardGap) {
          whitelistCard
          snoozeCard
        }

        resourceCard
        aboutCard
      }
      .padding(.horizontal, ProcessWatchLayout.pageHorizontal)
      .padding(.vertical, ProcessWatchLayout.pageVertical)
    }
  }

  private var generalCard: some View {
    DashboardCard {
      VStack(alignment: .leading, spacing: 14) {
        cardTitle("通用", icon: "switch.2", color: ProcessWatchTheme.blue)

        Toggle("允许系统异常通知", isOn: $settings.notificationsEnabled)

        Toggle(
          "登录时启动",
          isOn: Binding(
            get: { loginItem.isEnabled },
            set: { loginItem.setEnabled($0) }
          )
        )

        if let error = loginItem.lastError {
          Label(error, systemImage: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(ProcessWatchTheme.red)
        }

        separator

        settingStepper(
          title: "采样间隔",
          detail: "间隔越短越及时，但 ProcessWatch 自身唤醒次数也会增加。",
          value: $settings.samplingInterval,
          range: 1...30,
          step: 1,
          suffix: "秒"
        )
      }
    }
  }

  private var cpuCard: some View {
    thresholdCard(
      title: "CPU 异常",
      icon: "cpu",
      color: ProcessWatchTheme.amber,
      description: "100% 大约表示占满一个 CPU 核心，多线程进程可能超过 100%。"
    ) {
      settingStepper(
        title: "占用超过",
        value: $settings.cpuThreshold,
        range: 10...800,
        step: 10,
        suffix: "%"
      )
      settingStepper(
        title: "持续时间",
        value: $settings.cpuDuration,
        range: 10...900,
        step: 10,
        suffix: "秒"
      )
    }
  }

  private var memoryCard: some View {
    thresholdCard(
      title: "内存增长",
      icon: "memorychip",
      color: ProcessWatchTheme.teal,
      description: "检测单进程在时间窗口中的增长，不以系统内存使用百分比直接判定泄漏。"
    ) {
      settingStepper(
        title: "增长超过",
        value: $settings.memoryGrowthMB,
        range: 128...16_384,
        step: 128,
        suffix: "MB"
      )
      settingStepper(
        title: "观察窗口",
        value: $settings.memoryWindow,
        range: 60...3600,
        step: 60,
        suffix: "秒"
      )
    }
  }

  private var diskCard: some View {
    thresholdCard(
      title: "磁盘写入",
      icon: "internaldrive",
      color: ProcessWatchTheme.blue,
      description: "适合发现日志、缓存或文件生成循环。"
    ) {
      settingStepper(
        title: "写入超过",
        value: $settings.diskWriteMBps,
        range: 1...500,
        step: 1,
        suffix: "MB/s"
      )
      settingStepper(
        title: "持续时间",
        value: $settings.diskDuration,
        range: 10...900,
        step: 10,
        suffix: "秒"
      )
    }
  }

  private var stormCard: some View {
    thresholdCard(
      title: "进程风暴",
      icon: "square.stack.3d.up",
      color: ProcessWatchTheme.red,
      description: "repo-harness 孤儿实例会使用更具体的泄漏规则。"
    ) {
      settingStepper(
        title: "实例数超过",
        value: $settings.processStormInstanceThreshold,
        range: 2...200,
        step: 1,
        suffix: "个"
      )
      settingStepper(
        title: "持续时间",
        value: $settings.processStormDuration,
        range: 10...1800,
        step: 10,
        suffix: "秒"
      )
      settingStepper(
        title: "孤儿运行超过",
        value: $settings.repoHarnessOrphanDuration,
        range: 60...7200,
        step: 60,
        suffix: "秒"
      )
    }
  }

  private var whitelistCard: some View {
    DashboardCard {
      VStack(alignment: .leading, spacing: 12) {
        cardTitle("白名单", icon: "checkmark.shield", color: ProcessWatchTheme.teal)
        Text("白名单进程仍会采样，但不会生成异常提醒。优先按完整可执行路径保存。")
          .font(.caption)
          .foregroundStyle(ProcessWatchTheme.textSecondary)

        if settings.ignoredProcessNames.isEmpty {
          emptySettingText("暂无白名单。可在进程或异常页面添加。")
        } else {
          ForEach(settings.ignoredProcessNames.sorted(), id: \.self) { key in
            HStack(spacing: 8) {
              Text(settings.displayName(forSuppressionKey: key))
                .font(.system(.caption, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
              Spacer()
              Button("移除") { settings.unignoreKey(key) }
                .buttonStyle(ProcessWatchButtonStyle(kind: .subtle))
            }
          }
        }
      }
    }
  }

  private var snoozeCard: some View {
    DashboardCard {
      VStack(alignment: .leading, spacing: 12) {
        cardTitle("临时忽略", icon: "bell.slash", color: ProcessWatchTheme.blue)
        Text("临时忽略只暂停通知和异常事件，监测不会停止。")
          .font(.caption)
          .foregroundStyle(ProcessWatchTheme.textSecondary)

        if activeSnoozes.isEmpty {
          emptySettingText("暂无临时忽略。")
        } else {
          ForEach(activeSnoozes) { item in
            HStack(spacing: 8) {
              VStack(alignment: .leading, spacing: 2) {
                Text(settings.displayName(forSuppressionKey: item.key))
                  .font(.system(.caption, design: .monospaced))
                  .lineLimit(1)
                  .truncationMode(.middle)
                Text("恢复于 \(item.deadline.formatted(date: .omitted, time: .shortened))")
                  .font(.caption2)
                  .foregroundStyle(ProcessWatchTheme.textTertiary)
              }
              Spacer()
              Button("恢复") { settings.clearSnoozeKey(item.key) }
                .buttonStyle(ProcessWatchButtonStyle(kind: .subtle))
            }
          }
        }
      }
    }
  }

  private var resourceCard: some View {
    DashboardCard {
      VStack(alignment: .leading, spacing: 10) {
        cardTitle("资源释放与历史", icon: "shield.lefthalf.filled", color: ProcessWatchTheme.amber)
        Text("ProcessWatch 不提供虚假的系统“清内存”按钮。确认进程异常后，可优雅结束、只结束孤儿/高占用实例，必要时再强制退出。macOS 会自动回收进程资源。")
          .font(.callout)
          .foregroundStyle(ProcessWatchTheme.textSecondary)
        Text("异常历史和用户操作历史各保留最多 200 条；秒级性能曲线只保留在内存中的短窗口，不会长期写盘。")
          .font(.caption)
          .foregroundStyle(ProcessWatchTheme.textTertiary)
      }
    }
  }

  private var aboutCard: some View {
    DashboardCard {
      HStack(alignment: .center, spacing: 16) {
        Image(nsImage: NSApp.applicationIconImage)
          .resizable()
          .frame(width: 62, height: 62)
          .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: 4) {
          Text("ProcessWatch")
            .font(.title3.weight(.semibold))
          Text(ApplicationInfo.displayVersion)
            .font(.caption)
            .foregroundStyle(ProcessWatchTheme.textSecondary)
          Text("MIT License · 本地优先 · 不上传监控数据")
            .font(.caption)
            .foregroundStyle(ProcessWatchTheme.textTertiary)
        }

        Spacer()

        Button("关于") { ApplicationInfo.showAboutPanel() }
          .buttonStyle(ProcessWatchButtonStyle(kind: .secondary))
        Button("数据目录") { ApplicationInfo.openDataDirectory() }
          .buttonStyle(ProcessWatchButtonStyle(kind: .secondary))
        Button("复制诊断信息") { _ = ApplicationInfo.copyDiagnostics() }
          .buttonStyle(ProcessWatchButtonStyle(kind: .secondary))
        Button("退出 ProcessWatch", role: .destructive) {
          NSApplication.shared.terminate(nil)
        }
        .buttonStyle(ProcessWatchButtonStyle(kind: .danger))
      }
    }
  }

  private func thresholdCard<Content: View>(
    title: String,
    icon: String,
    color: Color,
    description: String,
    @ViewBuilder content: () -> Content
  ) -> some View {
    DashboardCard {
      VStack(alignment: .leading, spacing: 12) {
        cardTitle(title, icon: icon, color: color)
        content()
        Text(description)
          .font(.caption)
          .foregroundStyle(ProcessWatchTheme.textTertiary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func cardTitle(_ title: String, icon: String, color: Color) -> some View {
    Label(title, systemImage: icon)
      .font(.headline)
      .foregroundStyle(color)
  }

  private var separator: some View {
    Rectangle()
      .fill(ProcessWatchTheme.border)
      .frame(height: 1)
  }

  private func emptySettingText(_ text: String) -> some View {
    Text(text)
      .font(.caption)
      .foregroundStyle(ProcessWatchTheme.textSecondary)
      .frame(maxWidth: .infinity, minHeight: 52, alignment: .center)
      .background(
        ProcessWatchTheme.surfaceSoft,
        in: RoundedRectangle(cornerRadius: 9, style: .continuous)
      )
  }

  private func settingStepper(
    title: String,
    detail: String? = nil,
    value: Binding<Double>,
    range: ClosedRange<Double>,
    step: Double,
    suffix: String
  ) -> some View {
    HStack(alignment: .center, spacing: 10) {
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
        if let detail {
          Text(detail)
            .font(.caption2)
            .foregroundStyle(ProcessWatchTheme.textTertiary)
        }
      }
      Spacer()
      Stepper("", value: value, in: range, step: step)
        .labelsHidden()
      Text("\(value.wrappedValue, specifier: "%.0f") \(suffix)")
        .font(.system(.callout, design: .monospaced))
        .frame(width: 100, alignment: .trailing)
    }
  }
}
