import SwiftUI

struct OverviewView: View {
  @EnvironmentObject private var model: AppModel
  @State private var selectedGroupID: String?

  private let metricColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

  var body: some View {
    VStack(spacing: ProcessWatchLayout.sectionGap) {
      header

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
          footer: "\(model.processes.count) 进程 · \(model.totalOrphanCount) 孤儿 · \(model.activeAnomalyCount) 异常",
          systemImage: "thermometer.medium",
          accent: systemColor,
          statusText: systemStatus,
          statusColor: systemColor,
          points: model.processCountHistory
        )
      }

      HSplitView {
        processSection
          .frame(minWidth: 650, maxWidth: .infinity, maxHeight: .infinity)

        AnomalyActionPanel(group: selectedGroup)
          .frame(
            minWidth: 350,
            idealWidth: ProcessWatchLayout.detailPanelWidth,
            maxWidth: 470,
            maxHeight: .infinity
          )
      }
      .frame(maxHeight: .infinity)
    }
    .padding(.horizontal, ProcessWatchLayout.pageHorizontal)
    .padding(.vertical, ProcessWatchLayout.pageVertical)
    .onAppear { synchronizeSelection() }
    .onChange(of: overviewGroups.map(\.id)) { _ in synchronizeSelection() }
  }

  private var header: some View {
    HStack(spacing: 14) {
      SectionHeading(
        title: "系统概览",
        subtitle: model.isPaused
          ? "监控已暂停，当前数据不会继续刷新"
          : "聚焦持续异常，不因瞬时峰值打扰你"
      )

      Spacer()

      HStack(spacing: 8) {
        StatusPill(
          text: model.activeAnomalyCount > 0 ? "\(model.activeAnomalyCount) 个活动异常" : "当前稳定",
          color: model.activeAnomalyCount > 0 ? ProcessWatchTheme.red : ProcessWatchTheme.teal
        )

        if let lastSampleAt = model.lastSampleAt {
          Text("更新于 \(lastSampleAt.formatted(date: .omitted, time: .standard))")
            .font(.caption)
            .foregroundStyle(ProcessWatchTheme.textSecondary)
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

  private var processSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        VStack(alignment: .leading, spacing: 3) {
          Text("需要关注的进程")
            .font(.headline)
          Text("异常优先，其次按 CPU 合计排序；点击行后在右侧处理")
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
    default: return model.totalOrphanCount > 0 ? ProcessWatchTheme.amber : ProcessWatchTheme.teal
    }
  }

  private var systemStatus: String {
    if model.activeAnomalyCount > 0 { return "需处理" }
    switch model.system.thermalState {
    case .critical: return "临界"
    case .serious: return "严重"
    case .fair: return "偏高"
    case .nominal: return model.totalOrphanCount > 0 ? "需检查" : "正常"
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
