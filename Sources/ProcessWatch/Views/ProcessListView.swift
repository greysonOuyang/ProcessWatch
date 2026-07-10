import SwiftUI

struct ProcessListView: View {
  enum SortMode: String, CaseIterable, Identifiable {
    case cpu = "CPU"
    case memory = "内存"
    case diskWrite = "磁盘写入"
    case instances = "实例数"
    case orphans = "孤儿进程"

    var id: String { rawValue }
  }

  @EnvironmentObject private var model: AppModel
  @ObservedObject var settings: SettingsStore

  @State private var sortMode: SortMode = .cpu
  @State private var onlyAnomalies = false
  @State private var selectedGroupID: String?

  private var displayedGroups: [ProcessGroupSnapshot] {
    let filtered = model.processGroups.filter { group in
      !onlyAnomalies || !model.anomalyKinds(for: group).isEmpty
    }
    return filtered.sorted { lhs, rhs in
      switch sortMode {
      case .cpu: return lhs.cpuPercent > rhs.cpuPercent
      case .memory: return lhs.memoryBytes > rhs.memoryBytes
      case .diskWrite: return lhs.diskWriteBytesPerSecond > rhs.diskWriteBytesPerSecond
      case .instances: return lhs.instanceCount > rhs.instanceCount
      case .orphans: return lhs.orphanCount > rhs.orphanCount
      }
    }
  }

  var body: some View {
    VStack(spacing: ProcessWatchLayout.sectionGap) {
      header

      DashboardSplit {
        ProcessGroupTableView(
          groups: displayedGroups,
          selectedGroupID: $selectedGroupID,
          showsSearch: true
        )
      } trailing: {
        AnomalyActionPanel(group: selectedGroup)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .padding(.horizontal, ProcessWatchLayout.pageHorizontal)
    .padding(.vertical, ProcessWatchLayout.pageVertical)
    .onAppear { synchronizeSelection() }
    .onChange(of: displayedGroups.map(\.id)) { _ in synchronizeSelection() }
  }

  private var header: some View {
    PageHeaderBar {
      SectionHeading(
        title: "进程分析",
        subtitle: "按完整可执行文件路径聚合；展开后查看 PID、PPID、命令和工作目录"
      )
    } actions: {
      HStack(spacing: 10) {
        Toggle("仅异常", isOn: $onlyAnomalies)
          .toggleStyle(.switch)
          .controlSize(.small)

        Picker("排序", selection: $sortMode) {
          ForEach(SortMode.allCases) { mode in
            Text(mode.rawValue).tag(mode)
          }
        }
        .pickerStyle(.menu)
        .frame(width: 128)

        StatusPill(
          text: "\(displayedGroups.count) 组 · \(displayedGroups.reduce(0) { $0 + $1.instanceCount }) 实例",
          color: ProcessWatchTheme.blue
        )
      }
    }
  }

  private var selectedGroup: ProcessGroupSnapshot? {
    model.group(id: selectedGroupID) ?? displayedGroups.first
  }

  private func synchronizeSelection() {
    let ids = Set(displayedGroups.map(\.id))
    if let selectedGroupID, ids.contains(selectedGroupID) { return }
    selectedGroupID = displayedGroups.first?.id
  }
}
