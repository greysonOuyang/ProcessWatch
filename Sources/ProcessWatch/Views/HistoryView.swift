import AppKit
import SwiftUI

struct HistoryView: View {
  private enum Mode: String, CaseIterable, Identifiable {
    case anomalies = "异常记录"
    case actions = "操作记录"

    var id: String { rawValue }
  }

  @ObservedObject var history: HistoryStore
  @ObservedObject var actionHistory: ActionHistoryStore

  @State private var mode: Mode = .anomalies
  @State private var searchText = ""
  @State private var anomalyFilter = "全部"
  @State private var alertState: HistoryAlertState?

  private var filteredEvents: [AnomalyEvent] {
    history.events.filter { event in
      let matchesKind = anomalyFilter == "全部" || event.kind.rawValue == anomalyFilter
      let matchesSearch = searchText.isEmpty
        || event.processName.localizedCaseInsensitiveContains(searchText)
        || event.processPath.localizedCaseInsensitiveContains(searchText)
        || event.detail.localizedCaseInsensitiveContains(searchText)
      return matchesKind && matchesSearch
    }
  }

  private var filteredActions: [UserActionRecord] {
    actionHistory.records.filter { record in
      searchText.isEmpty
        || record.processName.localizedCaseInsensitiveContains(searchText)
        || record.processPath.localizedCaseInsensitiveContains(searchText)
        || record.action.rawValue.localizedCaseInsensitiveContains(searchText)
        || record.detail.localizedCaseInsensitiveContains(searchText)
    }
  }

  var body: some View {
    DashboardCard(padding: 0) {
      VStack(spacing: 0) {
        toolbar
        Rectangle().fill(ProcessWatchTheme.border).frame(height: 1)
        content
      }
    }
    .alert(item: $alertState) { state in
      switch state {
      case .confirmClear:
        return Alert(
          title: Text("清空\(mode.rawValue)？"),
          message: Text("该操作无法撤销。"),
          primaryButton: .destructive(Text("清空")) {
            if mode == .anomalies { history.clear() } else { actionHistory.clear() }
          },
          secondaryButton: .cancel()
        )
      case .message(let message):
        return Alert(
          title: Text("历史记录"),
          message: Text(message),
          dismissButton: .default(Text("好"))
        )
      }
    }
  }

  private var toolbar: some View {
    HStack(spacing: 10) {
      Picker("记录类型", selection: $mode) {
        ForEach(Mode.allCases) { item in
          Text(item.rawValue).tag(item)
        }
      }
      .pickerStyle(.segmented)
      .frame(width: 220)

      HStack(spacing: 8) {
        Image(systemName: "magnifyingglass")
          .foregroundStyle(ProcessWatchTheme.textTertiary)
        TextField("搜索进程、路径或内容", text: $searchText)
          .textFieldStyle(.plain)
        if !searchText.isEmpty {
          Button { searchText = "" } label: {
            Image(systemName: "xmark.circle.fill")
              .foregroundStyle(ProcessWatchTheme.textTertiary)
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 7)
      .background(
        ProcessWatchTheme.surfaceSoft,
        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .stroke(ProcessWatchTheme.border, lineWidth: 1)
      )
      .frame(maxWidth: 320)

      if mode == .anomalies {
        Picker("异常类型", selection: $anomalyFilter) {
          Text("全部").tag("全部")
          ForEach(AnomalyKind.allCases, id: \.rawValue) { kind in
            Text(kind.rawValue).tag(kind.rawValue)
          }
        }
        .pickerStyle(.menu)
        .frame(width: 150)
      }

      Spacer()

      StatusPill(
        text: mode == .anomalies ? "\(filteredEvents.count) 条" : "\(filteredActions.count) 条",
        color: ProcessWatchTheme.blue
      )

      Button("导出 JSON") { exportCurrentMode() }
        .buttonStyle(ProcessWatchButtonStyle(kind: .secondary))

      Button("清空", role: .destructive) {
        alertState = .confirmClear
      }
      .buttonStyle(ProcessWatchButtonStyle(kind: .subtle))
      .disabled(mode == .anomalies ? history.events.isEmpty : actionHistory.records.isEmpty)
    }
    .padding(12)
    .background(Color.black.opacity(0.12))
  }

  @ViewBuilder
  private var content: some View {
    switch mode {
    case .anomalies:
      if filteredEvents.isEmpty {
        emptyState(
          icon: "checkmark.shield.fill",
          title: history.events.isEmpty ? "暂无异常记录" : "没有匹配的异常记录",
          detail: "仅持续超过阈值的异常会写入本地历史，最多保留 200 条。",
          color: ProcessWatchTheme.teal
        )
      } else {
        ScrollView {
          LazyVStack(spacing: 0) {
            ForEach(filteredEvents) { event in
              EventRow(event: event)
                .padding(.horizontal, 16)
              Rectangle().fill(ProcessWatchTheme.border).frame(height: 1)
            }
          }
        }
      }
    case .actions:
      if filteredActions.isEmpty {
        emptyState(
          icon: "hand.tap.fill",
          title: actionHistory.records.isEmpty ? "暂无操作记录" : "没有匹配的操作记录",
          detail: "结束进程、忽略、白名单和脚本执行结果会记录在本机，最多保留 200 条。",
          color: ProcessWatchTheme.blue
        )
      } else {
        ScrollView {
          LazyVStack(spacing: 0) {
            ForEach(filteredActions) { record in
              ActionRecordRow(record: record)
                .padding(.horizontal, 16)
              Rectangle().fill(ProcessWatchTheme.border).frame(height: 1)
            }
          }
        }
      }
    }
  }

  private func emptyState(
    icon: String,
    title: String,
    detail: String,
    color: Color
  ) -> some View {
    VStack(spacing: 12) {
      Image(systemName: icon)
        .font(.system(size: 38))
        .foregroundStyle(color)
      Text(title)
        .font(.headline)
      Text(detail)
        .font(.caption)
        .foregroundStyle(ProcessWatchTheme.textSecondary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(40)
  }

  private func exportCurrentMode() {
    let panel = NSSavePanel()
    panel.title = "导出 ProcessWatch \(mode.rawValue)"
    panel.nameFieldStringValue = mode == .anomalies
      ? "processwatch-anomalies.json" : "processwatch-actions.json"
    panel.allowedFileTypes = ["json"]
    panel.canCreateDirectories = true
    guard panel.runModal() == .OK, let url = panel.url else { return }

    do {
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      encoder.dateEncodingStrategy = .iso8601
      let data: Data
      switch mode {
      case .anomalies:
        data = try encoder.encode(filteredEvents)
      case .actions:
        data = try encoder.encode(filteredActions)
      }
      try data.write(to: url, options: .atomic)
      alertState = .message("已导出到：\n\(url.path)")
    } catch {
      alertState = .message("导出失败：\(error.localizedDescription)")
    }
  }
}

private enum HistoryAlertState: Identifiable {
  case confirmClear
  case message(String)

  var id: String {
    switch self {
    case .confirmClear: return "confirm-clear"
    case .message(let message): return "message-\(message.hashValue)"
    }
  }
}
