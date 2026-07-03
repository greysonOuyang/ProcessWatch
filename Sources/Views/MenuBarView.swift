import AppKit
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ProcessWatch")
                        .font(.headline)
                    Text(model.isPaused ? "监控已暂停" : "正在监控")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if model.activeAnomalyCount > 0 {
                    Label("\(model.activeAnomalyCount)", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }

            HStack(spacing: 8) {
                compactMetric(title: "CPU", value: formatPercent(model.system.cpuPercent))
                compactMetric(title: "内存压力", value: model.system.memoryPressure.rawValue)
                compactMetric(title: "热状态", value: model.system.thermalState.rawValue)
            }

            Divider()

            Text("当前高占用进程组")
                .font(.caption)
                .foregroundStyle(.secondary)

            if model.topProcessGroups.isEmpty {
                Text("正在采集进程数据…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(model.topProcessGroups.prefix(5)) { group in
                    HStack(spacing: 8) {
                        Image(systemName: model.anomalyKinds(for: group).isEmpty ? "square.stack.3d.up" : "exclamationmark.triangle.fill")
                            .frame(width: 16)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(group.name) × \(group.instanceCount)")
                                .lineLimit(1)
                            if group.orphanCount > 0 {
                                Text("孤儿 \(group.orphanCount) · 最长 \(formatDuration(group.longestRuntime))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text(formatPercent(group.cpuPercent))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        Text(formatBytes(group.memoryBytes))
                            .frame(width: 72, alignment: .trailing)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .font(.callout)
                }
            }

            Divider()

            HStack {
                Button(model.isPaused ? "继续监控" : "暂停监控") {
                    model.togglePaused()
                }

                Button("打开主界面") {
                    WindowManager.shared.show(model: model)
                }
                .keyboardShortcut(.defaultAction)

                Spacer()

                Button("退出 ProcessWatch", role: .destructive) {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
        }
        .padding(14)
        .frame(width: 410)
    }

    private func compactMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .monospacedDigit()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
    }
}
