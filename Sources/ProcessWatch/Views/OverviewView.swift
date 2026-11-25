import SwiftUI

struct OverviewView: View {
  @EnvironmentObject private var model: AppModel
  @State private var selectedGroupID: String?

  private let metricColumns = Array(repeating: GridItem(.flexible(), spacing: 14), count: 4)

  /// Estimated height of everything above the split panes
  /// (header + hero + metric grid + section gaps + vertical padding).
  /// Used to give the split a sensible fixed height inside the ScrollView.
  private let topContentEstimate: CGFloat = 436

  var body: some View {
    GeometryReader { proxy in
      let splitHeight = max(440, proxy.size.height - topContentEstimate)

      ScrollView(.vertical) {
        VStack(spacing: ProcessWatchLayout.sectionGap) {
          header

          if model.activeIncident != nil || model.recentIncident != nil {
            SystemIncidentCard()
          }

          healthHero

          metricGrid

          DashboardSplit {
            processSection
          } trailing: {
            AnomalyActionPanel(group: selectedGroup)
          }
          .frame(height: splitHeight)
        }
        .padding(.horizontal, ProcessWatchLayout.pageHorizontal)
        .padding(.vertical, ProcessWatchLayout.pageVertical)
      }
    }
    .onAppear { synchronizeSelection() }
    .onChange(of: overviewGroups.map(\.id)) { _ in synchronizeSelection() }
  }

  private var metricGrid: some View {
    LazyVGrid(columns: metricColumns, spacing: ProcessWatchLayout.cardGap) {
        DashboardMetricCard(
          title: "CPU",
          value: formatPercent(model.system.cpuPercent),
          detail: "系统总占用",
          footer: "阈值 \(formatPercent(model.settings.cpuThreshold)) · \(ProcessInfo.processInfo.processorCount) 核心",
          systemImage: "cpu",
          accent: cpuColor,
          statusText: cpuStatus,
          statusColor: cpuColor,
          points: model.cpuHistory
        )

        DashboardMetricCard(
          title: "Memory",
          value: model.system.memoryPressure.rawValue,
          detail: formatPercent(model.system.memoryPercent),
          footer: "Swap \(formatBytes(model.system.swapUsedBytes)) · 压缩 \(formatBytes(model.system.compressedBytes))",
          systemImage: "memorychip",
          accent: memoryColor,
          statusText: memoryStatus,
          statusColor: memoryColor,
          points: model.memoryHistory
        )

        DashboardMetricCard(
          title: "Disk I/O",
          value: formatRate(model.totalDiskWriteBytesPerSecond),
          detail: "当前写入",
          footer: "读取 \(formatRate(model.totalDiskReadBytesPerSecond))",
          systemImage: "internaldrive",
          accent: diskColor,
          statusText: diskStatus,
          statusColor: diskColor,
          points: model.diskWriteHistory
        )

        DashboardMetricCard(
          title: "System",
          value: model.system.thermalState.rawValue,
          detail: thermalDescription,
          footer: "\(model.processes.count) 进程 · \(model.anomalyContributorGroupCount) 异常贡献组 · \(model.actionableAnomalyGroupCount) 可处理",
          systemImage: "thermometer.medium",
          accent: systemColor,
          statusText: systemStatus,
          statusColor: systemColor,
          points: model.processCountHistory
        )
      }
  }

  private var header: some View {
    PageHeaderBar {
      SectionHeading(
        title: "系统概览",
        subtitle: model.isPaused
          ? "监控已暂停，当前数据不会继续刷新"
          : "聚焦持续异常，不因瞬时峰值打扰你"
      )
    } actions: {
      HStack(spacing: 8) {
        if let lastSampleAt = model.lastSampleAt {
          Label(
            "更新于 \(lastSampleAt.formatted(date: .omitted, time: .standard))",
            systemImage: "clock.arrow.circlepath"
          )
          .font(.caption)
          .monospacedDigit()
          .foregroundStyle(ProcessWatchTheme.textSecondary)
          .lineLimit(1)
        }

        Button {
          model.togglePaused()
        } label: {
          Label(
            model.isPaused ? "继续" : "暂停",
            systemImage: model.isPaused ? "play.fill" : "pause.fill"
          )
        }
        .buttonStyle(ProcessWatchButtonStyle(kind: .secondary))
      }
    }
  }

  // MARK: - Health hero

  private var healthHero: some View {
    DashboardCard(padding: 0, elevated: true) {
      HStack(spacing: 0) {
        HStack(spacing: 18) {
          ZStack {
            HealthRing(progress: Double(healthScore) / 100, color: healthColor, lineWidth: 8)
              .frame(width: 74, height: 74)
            VStack(spacing: 0) {
              Text("\(healthScore)")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(healthColor)
              Text("健康分")
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(ProcessWatchTheme.textTertiary)
            }
          }

          VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
              Text(healthTitle)
                .font(.title3.weight(.bold))
                .foregroundStyle(ProcessWatchTheme.textPrimary)
              StatusPill(
                text: model.activeAnomalyCount > 0 ? "\(model.activeAnomalyCount) 个活动异常" : "当前稳定",
                color: model.activeAnomalyCount > 0 ? ProcessWatchTheme.red : ProcessWatchTheme.teal
              )
            }
            Text(healthDescription)
              .font(.caption)
              .foregroundStyle(ProcessWatchTheme.textSecondary)
              .lineLimit(2)
          }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)

        Spacer(minLength: 8)

        Rectangle()
          .fill(ProcessWatchTheme.border)
          .frame(width: 1, height: 64)

        HStack(spacing: 0) {
          heroStat(title: "进程", value: "\(model.processes.count)", systemImage: "square.stack.3d.up")
          heroStat(
            title: "可处理",
            value: "\(model.actionableAnomalyGroupCount)",
            systemImage: "checkmark.shield",
            tint: model.actionableAnomalyGroupCount > 0 ? ProcessWatchTheme.amber : nil
          )
          heroStat(
            title: "异常信号",
            value: "\(model.activeAnomalyCount)",
            systemImage: "exclamationmark.triangle",
            tint: model.activeAnomalyCount > 0 ? ProcessWatchTheme.red : nil
          )

          if model.activeAnomalyCount > 0 {
            Button {
              model.selectedSection = .alerts
            } label: {
              Label(
                model.actionableAnomalyGroupCount > 0 ? "查看可处理项" : "查看详情",
                systemImage: "arrow.right.circle.fill"
              )
            }
            .buttonStyle(ProcessWatchButtonStyle(kind: .primary))
            .padding(.leading, 6)
          }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
      }
      .background(
        LinearGradient(
          colors: [healthColor.opacity(0.07), Color.clear],
          startPoint: .leading,
          endPoint: .trailing
        )
      )
    }
  }

  private func heroStat(
    title: String,
    value: String,
    systemImage: String,
    tint: Color? = nil
  ) -> some View {
    VStack(spacing: 4) {
      Image(systemName: systemImage)
        .font(.caption)
        .foregroundStyle(tint ?? ProcessWatchTheme.textTertiary)
      Text(value)
        .font(.system(.title3, design: .rounded).weight(.bold))
        .monospacedDigit()
        .foregroundStyle(tint ?? ProcessWatchTheme.textPrimary)
      Text(title)
        .font(.caption2)
        .foregroundStyle(ProcessWatchTheme.textTertiary)
    }
    .frame(minWidth: 58)
  }

  private var healthScore: Int {
    var score = 100.0
    let cpuThreshold = max(model.settings.cpuThreshold, 1)
    score -= min(model.system.cpuPercent / cpuThreshold, 1.5) * 18
    switch model.system.memoryPressure {
    case .warning: score -= 12
    case .critical: score -= 26
    case .unknown: score -= 4
    default: break
    }
    switch model.system.thermalState {
    case .fair: score -= 8
    case .serious: score -= 18
    case .critical: score -= 28
    default: break
    }
    score -= min(Double(model.activeAnomalyCount) * 7, 21)
    return Int(max(5, min(100, score)).rounded())
  }

  private var healthColor: Color {
    if healthScore >= 80 { return ProcessWatchTheme.teal }
    if healthScore >= 60 { return ProcessWatchTheme.amber }
    return ProcessWatchTheme.red
  }

  private var healthTitle: String {
    if model.isPaused { return "监控已暂停" }
    if healthScore >= 80 { return "系统运行状态良好" }
    if healthScore >= 60 { return "系统负载偏高，建议关注" }
    return "系统存在风险，建议立即检查"
  }

  private var healthDescription: String {
    if model.isPaused {
      return "采样与异常检测已暂停，点击右上角“继续”恢复监控。"
    }
    if model.activeAnomalyCount > 0 {
      if model.actionableAnomalyGroupCount > 0 {
        return "检测到 \(model.activeAnomalyCount) 个持续异常信号，其中 \(model.actionableAnomalyGroupCount) 个进程组通过安全操作门禁。"
      }
      return "检测到 \(model.activeAnomalyCount) 个持续异常信号，但当前没有通过安全校验的可操作进程；请查看详情继续调查。"
    }
    return "CPU、内存、磁盘与进程数量均在安全范围内，瞬时峰值不会打扰你。"
  }

  // MARK: - Process section

  private var processSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        VStack(alignment: .leading, spacing: 3) {
          Text("需要关注的进程")
            .font(.headline)
          Text("按持续异常证据和嫌疑分排序；点击行后查看依据并安全处理")
            .font(.caption)
            .foregroundStyle(ProcessWatchTheme.textSecondary)
        }
        Spacer()
        Text("每 \(Int(model.settings.samplingInterval)) 秒采样")
          .font(.caption)
          .foregroundStyle(ProcessWatchTheme.textTertiary)
      }

      ProcessGroupTableView(
        groups: overviewGroups,
        selectedGroupID: $selectedGroupID,
        maxRows: 8,
        showsSearch: false
      )
    }
  }

  private var overviewGroups: [ProcessGroupSnapshot] {
    var seen = Set<String>()
    return (model.anomalousGroups + model.topProcessGroups)
      .filter { seen.insert($0.id).inserted }
      .prefix(10)
      .map { $0 }
  }

  private var selectedGroup: ProcessGroupSnapshot? {
    model.group(id: selectedGroupID) ?? model.suggestedActionGroup
  }

  private func synchronizeSelection() {
    let available = Set(overviewGroups.map(\.id))
    if let selectedGroupID, available.contains(selectedGroupID) { return }
    selectedGroupID = model.suggestedActionGroup?.id ?? overviewGroups.first?.id
  }

  private var cpuColor: Color {
    if model.system.cpuPercent >= model.settings.cpuThreshold { return ProcessWatchTheme.red }
    if model.system.cpuPercent >= model.settings.cpuThreshold * 0.65 { return ProcessWatchTheme.amber }
    return ProcessWatchTheme.teal
  }

  private var cpuStatus: String {
    if model.system.cpuPercent >= model.settings.cpuThreshold { return "高" }
    if model.system.cpuPercent >= model.settings.cpuThreshold * 0.65 { return "偏高" }
    return "正常"
  }

  private var memoryColor: Color {
    switch model.system.memoryPressure {
    case .critical: return ProcessWatchTheme.red
    case .warning: return ProcessWatchTheme.amber
    default: return ProcessWatchTheme.teal
    }
  }

  private var memoryStatus: String {
    switch model.system.memoryPressure {
    case .critical: return "严重"
    case .warning: return "偏高"
    case .normal: return "正常"
    case .unknown: return "未知"
    }
  }

  private var diskColor: Color {
    let threshold = model.settings.diskWriteMBps * 1_048_576
    if model.totalDiskWriteBytesPerSecond >= threshold { return ProcessWatchTheme.red }
    if model.totalDiskWriteBytesPerSecond >= threshold * 0.5 { return ProcessWatchTheme.amber }
    return ProcessWatchTheme.blue
  }

  private var diskStatus: String {
    let threshold = model.settings.diskWriteMBps * 1_048_576
    if model.totalDiskWriteBytesPerSecond >= threshold { return "繁忙" }
    if model.totalDiskWriteBytesPerSecond >= threshold * 0.5 { return "活跃" }
    return "正常"
  }

  private var systemColor: Color {
    if model.activeAnomalyCount > 0 { return ProcessWatchTheme.red }
    switch model.system.thermalState {
    case .critical, .serious: return ProcessWatchTheme.red
    case .fair: return ProcessWatchTheme.amber
    default: return ProcessWatchTheme.teal
    }
  }

  private var systemStatus: String {
    if model.activeAnomalyCount > 0 { return "需处理" }
    switch model.system.thermalState {
    case .critical: return "临界"
    case .serious: return "严重"
    case .fair: return "偏高"
    case .nominal: return "正常"
    case .unknown: return "未知"
    }
  }

  private var thermalDescription: String {
    switch model.system.thermalState {
    case .nominal: return "系统温控正常"
    case .fair: return "温度升高，尚未明显限频"
    case .serious: return "系统已开始限制性能"
    case .critical: return "系统正在显著限制性能"
    case .unknown: return "暂时无法读取"
    }
  }
}
