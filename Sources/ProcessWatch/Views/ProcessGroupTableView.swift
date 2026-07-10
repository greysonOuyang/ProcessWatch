import SwiftUI

struct ProcessGroupTableView: View {
  @EnvironmentObject private var model: AppModel

  let groups: [ProcessGroupSnapshot]
  @Binding var selectedGroupID: String?
  var maxRows: Int? = nil
  var showsSearch = false

  @State private var expandedGroups: Set<String> = []
  @State private var searchText = ""

  private var trimmedSearchText: String {
    searchText.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var visibleGroups: [ProcessGroupSnapshot] {
    let query = trimmedSearchText
    let filtered: [ProcessGroupSnapshot]
    if query.isEmpty {
      filtered = groups
    } else {
      filtered = groups.filter { group in
        group.name.localizedCaseInsensitiveContains(query)
          || group.path.localizedCaseInsensitiveContains(query)
          || group.processes.contains { $0.matches(searchText: query) }
      }
    }
    if let maxRows { return Array(filtered.prefix(maxRows)) }
    return filtered
  }

  private var hasSearchFilter: Bool {
    !trimmedSearchText.isEmpty
  }

  private var allVisibleExpanded: Bool {
    let ids = visibleGroups.map(\.id)
    return !ids.isEmpty && ids.allSatisfy { expandedGroups.contains($0) }
  }

  var body: some View {
    DashboardCard(padding: 0) {
      VStack(spacing: 0) {
        if showsSearch {
          searchBar
          tableTools
          separator
        }

        groupHeader
        separator

        if visibleGroups.isEmpty {
          emptyState
        } else {
          ScrollView {
            LazyVStack(spacing: 0) {
              ForEach(visibleGroups) { group in
                groupRow(group)
                if expandedGroups.contains(group.id) {
                  processRows(group)
                }
                separator
              }
            }
          }
        }
      }
    }
  }

  private var searchBar: some View {
    HStack(spacing: 10) {
      Image(systemName: "magnifyingglass")
        .foregroundStyle(ProcessWatchTheme.textTertiary)
      TextField("搜索进程、命令、PID 或工作目录", text: $searchText)
        .textFieldStyle(.plain)
      if !searchText.isEmpty {
        Button {
          searchText = ""
        } label: {
          Image(systemName: "xmark.circle.fill")
            .foregroundStyle(ProcessWatchTheme.textTertiary)
        }
        .buttonStyle(.plain)
      }
      Text("\(visibleGroups.count) 组")
        .font(.caption)
        .foregroundStyle(ProcessWatchTheme.textSecondary)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 11)
    .background(Color.black.opacity(0.14))
  }

  private var tableTools: some View {
    HStack(spacing: 8) {
      Text(hasSearchFilter ? "匹配 \(visibleGroups.count)，共 \(groups.count) 组" : "显示 \(visibleGroups.count)，共 \(groups.count) 组")
        .font(.caption)
        .foregroundStyle(ProcessWatchTheme.textSecondary)

      Spacer(minLength: 8)

      Button(allVisibleExpanded ? "收起结果" : "展开结果") {
        toggleVisibleExpansion()
      }
      .disabled(visibleGroups.isEmpty)
      .buttonStyle(ProcessWatchButtonStyle(kind: .subtle))

      if hasSearchFilter {
        Button("清除") { searchText = "" }
          .buttonStyle(ProcessWatchButtonStyle(kind: .subtle))
      }
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 8)
    .background(Color.black.opacity(0.08))
  }

  private var groupHeader: some View {
    HStack(spacing: 10) {
      Color.clear.frame(width: 18, height: 1)
      Text("进程组")
        .frame(maxWidth: .infinity, alignment: .leading)
      Text("CPU")
        .frame(width: 74, alignment: .trailing)
      Text("内存")
        .frame(width: 88, alignment: .trailing)
      Text("孤儿")
        .frame(width: 44, alignment: .trailing)
      Text("最长运行")
        .frame(width: 82, alignment: .trailing)
    }
    .font(.caption.weight(.medium))
    .foregroundStyle(ProcessWatchTheme.textSecondary)
    .padding(.horizontal, 14)
    .padding(.vertical, 9)
    .background(Color.black.opacity(0.12))
  }

  private var emptyState: some View {
    VStack(spacing: 10) {
      Image(systemName: model.processes.isEmpty ? "hourglass" : "magnifyingglass")
        .font(.system(size: 30))
        .foregroundStyle(ProcessWatchTheme.textTertiary)
      Text(model.processes.isEmpty ? "正在采集进程数据" : "没有匹配的进程组")
        .font(.headline)
      Text(
        model.processes.isEmpty
          ? "通常需要两个采样周期才能计算 CPU 与 I/O 速率。"
          : "修改搜索条件或关闭筛选条件。"
      )
      .font(.caption)
      .foregroundStyle(ProcessWatchTheme.textSecondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(40)
  }

  private func groupRow(_ group: ProcessGroupSnapshot) -> some View {
    let kinds = model.anomalyKinds(for: group)
    let isSelected = selectedGroupID == group.id

    return HStack(spacing: 10) {
      Button {
        toggleExpansion(group.id)
      } label: {
        Image(systemName: expandedGroups.contains(group.id) ? "chevron.down" : "chevron.right")
          .font(.caption2.weight(.bold))
          .frame(width: 18)
          .foregroundStyle(ProcessWatchTheme.textTertiary)
      }
      .buttonStyle(.plain)

      processIcon(group: group, kinds: kinds)

      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 6) {
          Text("\(group.name) × \(group.instanceCount)")
            .font(.system(size: 14, weight: .semibold))
            .lineLimit(1)

          if let affiliation = group.affiliationSummary {
            StatusPill(text: affiliation, color: ProcessWatchTheme.amber)
          }
          if let kind = kinds.sorted(by: { $0.rawValue < $1.rawValue }).first {
            StatusPill(text: kind.shortName, color: ProcessWatchTheme.red)
          }
          if model.settings.isSnoozed(group) {
            StatusPill(text: "临时忽略", color: ProcessWatchTheme.blue)
          } else if model.settings.isIgnored(group) {
            StatusPill(text: "白名单", color: ProcessWatchTheme.teal)
          }
        }

        Text(group.path.isEmpty ? "无法读取可执行文件路径" : group.path)
          .font(.system(.caption, design: .monospaced))
          .foregroundStyle(ProcessWatchTheme.textSecondary)
          .lineLimit(1)
          .truncationMode(.middle)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      metric(
        formatPercent(group.cpuPercent),
        width: 74,
        color: group.cpuPercent >= model.settings.cpuThreshold
          ? ProcessWatchTheme.red : ProcessWatchTheme.amber
      )
      metric(formatBytes(group.memoryBytes), width: 88, color: ProcessWatchTheme.textPrimary)
      metric(
        "\(group.orphanCount)",
        width: 44,
        color: group.orphanCount > 0 ? ProcessWatchTheme.amber : ProcessWatchTheme.textSecondary
      )
      metric(
        formatCompactDuration(group.longestRuntime),
        width: 82,
        color: ProcessWatchTheme.textSecondary
      )
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .background(isSelected ? ProcessWatchTheme.surfaceSelected : Color.clear)
    .contentShape(Rectangle())
    .onTapGesture {
      selectedGroupID = group.id
    }
    .contextMenu {
      Button("展开 / 收起") { toggleExpansion(group.id) }
      Button("在 Finder 中显示") { _ = ProcessActionService.reveal(group) }
      Button("复制代表命令") { _ = ProcessActionService.copyCommand(group) }
    }
  }

  private func processRows(_ group: ProcessGroupSnapshot) -> some View {
    VStack(spacing: 0) {
      processHeader

      ForEach(group.processes) { process in
        HStack(spacing: 10) {
          Text("\(process.pid)")
            .frame(width: 58, alignment: .trailing)
          Text("\(process.ppid)")
            .frame(width: 58, alignment: .trailing)

          VStack(alignment: .leading, spacing: 3) {
            Text(process.commandLine.isEmpty ? process.path : process.commandLine)
              .font(.system(.caption, design: .monospaced).weight(.medium))
              .lineLimit(1)
              .truncationMode(.middle)
            HStack(spacing: 8) {
              Text(process.parentName.isEmpty ? "父进程未知" : "父进程：\(process.parentName)")
              if !process.workingDirectory.isEmpty {
                Text(process.workingDirectory)
                  .lineLimit(1)
                  .truncationMode(.middle)
              }
            }
            .font(.caption2)
            .foregroundStyle(ProcessWatchTheme.textTertiary)
          }
          .frame(maxWidth: .infinity, alignment: .leading)

          metric(formatPercent(process.cpuPercent), width: 66, color: ProcessWatchTheme.amber)
          metric(formatBytes(process.memoryBytes), width: 82, color: ProcessWatchTheme.textSecondary)

          HStack(spacing: 4) {
            Circle()
              .fill(process.isOrphan ? ProcessWatchTheme.amber : ProcessWatchTheme.teal)
              .frame(width: 6, height: 6)
            Text(process.isOrphan ? "孤儿" : "正常")
          }
          .font(.caption2)
          .foregroundStyle(process.isOrphan ? ProcessWatchTheme.amber : ProcessWatchTheme.textSecondary)
          .frame(width: 54, alignment: .trailing)
        }
        .padding(.leading, 42)
        .padding(.trailing, 14)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.12))
        .contextMenu {
          Button("在 Finder 中显示") { _ = ProcessActionService.reveal(process) }
          Button("打开工作目录") { _ = ProcessActionService.openWorkingDirectory(process) }
          Button("复制完整命令") { _ = ProcessActionService.copyCommand(process) }
        }

        separator
      }
    }
  }

  private var processHeader: some View {
    HStack(spacing: 10) {
      Text("PID").frame(width: 58, alignment: .trailing)
      Text("PPID").frame(width: 58, alignment: .trailing)
      Text("完整命令 / 父进程 / 工作目录").frame(maxWidth: .infinity, alignment: .leading)
      Text("CPU").frame(width: 66, alignment: .trailing)
      Text("内存").frame(width: 82, alignment: .trailing)
      Text("状态").frame(width: 54, alignment: .trailing)
    }
    .font(.caption2.weight(.medium))
    .foregroundStyle(ProcessWatchTheme.textTertiary)
    .padding(.leading, 42)
    .padding(.trailing, 14)
    .padding(.vertical, 7)
    .background(Color.black.opacity(0.20))
  }

  private var separator: some View {
    Rectangle()
      .fill(ProcessWatchTheme.border)
      .frame(height: 1)
  }

  private func toggleExpansion(_ id: String) {
    selectedGroupID = id
    if expandedGroups.contains(id) {
      expandedGroups.remove(id)
    } else {
      expandedGroups.insert(id)
    }
  }

  private func toggleVisibleExpansion() {
    let ids = Set(visibleGroups.map(\.id))
    guard !ids.isEmpty else { return }
    if allVisibleExpanded {
      expandedGroups.subtract(ids)
    } else {
      expandedGroups.formUnion(ids)
      selectedGroupID = visibleGroups.first?.id ?? selectedGroupID
    }
  }

  private func processIcon(group: ProcessGroupSnapshot, kinds: Set<AnomalyKind>) -> some View {
    ZStack {
      RoundedRectangle(cornerRadius: 7, style: .continuous)
        .fill((kinds.isEmpty ? ProcessWatchTheme.teal : ProcessWatchTheme.red).opacity(0.12))
      Image(systemName: group.affiliationSummary == nil ? "terminal" : "shippingbox.fill")
        .foregroundStyle(kinds.isEmpty ? ProcessWatchTheme.teal : ProcessWatchTheme.red)
    }
    .frame(width: 30, height: 30)
  }

  private func metric(_ text: String, width: CGFloat, color: Color) -> some View {
    Text(text)
      .font(.system(.callout, design: .monospaced).weight(.medium))
      .foregroundStyle(color)
      .frame(width: width, alignment: .trailing)
      .lineLimit(1)
      .minimumScaleFactor(0.68)
  }
}

extension AnomalyKind {
  var shortName: String {
    switch self {
    case .cpu: return "高 CPU"
    case .memoryGrowth: return "内存增长"
    case .diskWrite: return "持续写盘"
    case .processStorm: return "进程风暴"
    case .repoHarnessLeak: return "疑似泄漏"
    }
  }
}
