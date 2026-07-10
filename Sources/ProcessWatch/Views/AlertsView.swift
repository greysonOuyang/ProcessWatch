import SwiftUI

struct AlertsView: View {
  private enum Mode: String, CaseIterable, Identifiable {
    case active = "活动异常"
    case history = "历史记录"

    var id: String { rawValue }
  }

  @EnvironmentObject private var model: AppModel
  @State private var mode: Mode = .active
  @State private var selectedGroupID: String?

  var body: some View {
    VStack(spacing: ProcessWatchLayout.sectionGap) {
      header

      Picker("异常视图", selection: $mode) {
        ForEach(Mode.allCases) { item in
          Text(item.rawValue).tag(item)
        }
      }
      .pickerStyle(.segmented)
      .frame(width: 300)
      .frame(maxWidth: .infinity, alignment: .leading)

      Group {
        switch mode {
        case .active:
          activeContent
        case .history:
          HistoryView(history: model.history, actionHistory: model.actionHistory)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .padding(.horizontal, ProcessWatchLayout.pageHorizontal)
    .padding(.vertical, ProcessWatchLayout.pageVertical)
    .onAppear { synchronizeSelection() }
    .onChange(of: model.anomalousGroups.map(\.id)) { _ in synchronizeSelection() }
  }

  private var header: some View {
    PageHeaderBar {
      SectionHeading(
        title: "异常中心",
        subtitle: "处理当前问题，并回溯异常触发与用户操作记录"
      )
    } actions: {
      HStack(spacing: 8) {
        StatusPill(
          text: model.activeAnomalyCount > 0 ? "\(model.activeAnomalyCount) 个活动异常" : "无活动异常",
          color: model.activeAnomalyCount > 0 ? ProcessWatchTheme.red : ProcessWatchTheme.teal
        )
        StatusPill(
          text: "\(model.history.events.count) 条历史",
          color: ProcessWatchTheme.blue
        )
      }
    }
  }

  @ViewBuilder
  private var activeContent: some View {
    if model.anomalousGroups.isEmpty {
      DashboardSplit {
        DashboardCard {
          VStack(spacing: 14) {
            Image(systemName: "checkmark.shield.fill")
              .font(.system(size: 42))
              .foregroundStyle(ProcessWatchTheme.teal)
            Text("当前没有持续异常")
              .font(.title3.weight(.semibold))
            Text("瞬时峰值不会进入异常历史。ProcessWatch 会继续监测 CPU、内存增长、持续写盘和进程风暴。")
              .font(.callout)
              .foregroundStyle(ProcessWatchTheme.textSecondary)
              .multilineTextAlignment(.center)
              .frame(maxWidth: 520)
            Button("查看历史记录") {
              mode = .history
            }
            .buttonStyle(ProcessWatchButtonStyle(kind: .primary))
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .padding(30)
        }
      } trailing: {
        recentHistory
      }
    } else {
      DashboardSplit {
        ProcessGroupTableView(
          groups: model.anomalousGroups,
          selectedGroupID: $selectedGroupID,
          showsSearch: false
        )
      } trailing: {
        AnomalyActionPanel(group: selectedGroup)
      }
    }
  }

  private var recentHistory: some View {
    DashboardCard(padding: 0, elevated: true) {
      VStack(spacing: 0) {
        HStack {
          VStack(alignment: .leading, spacing: 3) {
            Text("最近异常")
              .font(.headline)
            Text("这里只展示已触发的持续异常")
              .font(.caption2)
              .foregroundStyle(ProcessWatchTheme.textSecondary)
          }
          Spacer()
          Button("全部") { mode = .history }
            .buttonStyle(.plain)
            .foregroundStyle(ProcessWatchTheme.amber)
        }
        .padding(14)

        Rectangle().fill(ProcessWatchTheme.border).frame(height: 1)

        if model.history.events.isEmpty {
          Text("暂无历史记录")
            .font(.callout)
            .foregroundStyle(ProcessWatchTheme.textSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
        } else {
          ScrollView {
            LazyVStack(spacing: 0) {
              ForEach(model.history.events.prefix(8)) { event in
                EventRow(event: event)
                  .padding(.horizontal, 14)
                Rectangle().fill(ProcessWatchTheme.border).frame(height: 1)
              }
            }
          }
        }
      }
    }
  }

  private var selectedGroup: ProcessGroupSnapshot? {
    model.group(id: selectedGroupID) ?? model.anomalousGroups.first
  }

  private func synchronizeSelection() {
    let ids = Set(model.anomalousGroups.map(\.id))
    if let selectedGroupID, ids.contains(selectedGroupID) { return }
    selectedGroupID = model.anomalousGroups.first?.id
  }
}
