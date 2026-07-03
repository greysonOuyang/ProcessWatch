import SwiftUI

struct OverviewView: View {
    @EnvironmentObject private var model: AppModel

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private let memoryColumns = [
        GridItem(.adaptive(minimum: 135), spacing: 10)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("系统概览")
                            .font(.largeTitle.bold())
                        Text(model.isPaused ? "监控已暂停" : "每 \(Int(model.settings.samplingInterval)) 秒采样一次")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(model.isPaused ? "继续监控" : "暂停监控") {
                        model.togglePaused()
                    }
                }

                LazyVGrid(columns: columns, spacing: 12) {
                    MetricCard(
                        title: "CPU",
                        value: formatPercent(model.system.cpuPercent),
                        subtitle: "系统总 CPU 使用率",
                        systemImage: "cpu"
                    )
                    MetricCard(
                        title: "内存压力",
                        value: model.system.memoryPressure.rawValue,
                        subtitle: memoryPressureDescription,
                        systemImage: "memorychip"
                    )
                    MetricCard(
                        title: "热状态",
                        value: model.system.thermalState.rawValue,
                        subtitle: thermalDescription,
                        systemImage: "thermometer.medium"
                    )
                }

                GroupBox {
                    LazyVGrid(columns: memoryColumns, spacing: 10) {
                        memoryMetric(
                            title: "物理内存",
                            value: "\(formatBytes(model.system.memoryUsedBytes)) / \(formatBytes(model.system.memoryTotalBytes))",
                            subtitle: formatPercent(model.system.memoryPercent)
                        )
                        memoryMetric(
                            title: "Swap 使用量",
                            value: formatBytes(model.system.swapUsedBytes),
                            subtitle: model.system.swapTotalBytes > 0 ? "总计 \(formatBytes(model.system.swapTotalBytes))" : "当前未启用或无法读取"
                        )
                        memoryMetric(
                            title: "压缩内存",
                            value: formatBytes(model.system.compressedBytes),
                            subtitle: "系统压缩页占用"
                        )
                        memoryMetric(
                            title: "可回收缓存",
                            value: formatBytes(model.system.reclaimableBytes),
                            subtitle: "非活跃、推测及可清除页估算"
                        )
                        memoryMetric(
                            title: "最近增长速度",
                            value: formatSignedRate(model.system.memoryGrowthBytesPerSecond),
                            subtitle: "相邻采样间的系统内存变化"
                        )
                    }
                    .padding(.vertical, 4)
                } label: {
                    Label("内存详情", systemImage: "chart.bar.doc.horizontal")
                        .font(.headline)
                }

                GroupBox {
                    VStack(spacing: 0) {
                        if model.topProcessGroups.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: "waveform.path.ecg")
                                    .font(.system(size: 30))
                                    .foregroundStyle(.secondary)
                                Text("正在采集")
                                    .font(.headline)
                                Text("第二次采样后会显示进程组 CPU 使用率。")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 180)
                        } else {
                            ForEach(model.topProcessGroups.prefix(6)) { group in
                                ProcessGroupSummaryRow(group: group, kinds: model.anomalyKinds(for: group))
                                if group.id != model.topProcessGroups.prefix(6).last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                } label: {
                    Label("资源占用较高的进程组", systemImage: "chart.bar.xaxis")
                        .font(.headline)
                }

                GroupBox {
                    if model.history.events.isEmpty {
                        Text("还没有检测到持续异常或进程风暴。")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(model.history.events.prefix(5)) { event in
                                EventRow(event: event)
                                if event.id != model.history.events.prefix(5).last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                } label: {
                    Label("最近异常", systemImage: "exclamationmark.triangle")
                        .font(.headline)
                }
            }
            .padding(24)
        }
    }

    private var memoryPressureDescription: String {
        let suffix = model.system.memoryPressureIsEstimated ? "（估算）" : ""
        switch model.system.memoryPressure {
        case .normal: return "系统内存调度正常\(suffix)"
        case .warning: return "内存回收与压缩活动增加\(suffix)"
        case .critical: return "内存资源紧张，建议检查增长进程\(suffix)"
        case .unknown: return "暂时无法读取"
        }
    }

    private var thermalDescription: String {
        switch model.system.thermalState {
        case .nominal: return "系统温控正常"
        case .fair: return "温度升高，尚未明显限制性能"
        case .serious: return "系统已开始限制性能"
        case .critical: return "系统正在显著限制性能"
        case .unknown: return "暂时无法读取"
        }
    }

    private func memoryMetric(title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .topLeading)
        .padding(10)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 9))
    }
}

private struct ProcessGroupSummaryRow: View {
    let group: ProcessGroupSnapshot
    let kinds: Set<AnomalyKind>

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: kinds.isEmpty ? "square.stack.3d.up" : "exclamationmark.triangle.fill")
                .frame(width: 20)
                .foregroundStyle(kinds.isEmpty ? Color(nsColor: .secondaryLabelColor) : Color.orange)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("\(group.name) × \(group.instanceCount)")
                        .fontWeight(.medium)
                    if group.orphanCount > 0 {
                        Text("孤儿 \(group.orphanCount)")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                    if let affiliation = group.affiliationSummary {
                        Text(affiliation)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Text("最长运行 \(formatDuration(group.longestRuntime))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            metric("CPU 合计", formatPercent(group.cpuPercent))
            metric("内存合计", formatBytes(group.memoryBytes))
            metric("写入", formatRate(group.diskWriteBytesPerSecond))
        }
        .padding(.vertical, 10)
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).monospacedDigit()
        }
        .frame(width: 92, alignment: .trailing)
    }
}

struct EventRow: View {
    let event: AnomalyEvent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(event.processName).fontWeight(.medium)
                    Text(event.kind.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(event.date, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(event.detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 10)
    }

    private var icon: String {
        switch event.kind {
        case .cpu: return "cpu"
        case .memoryGrowth: return "memorychip"
        case .diskWrite: return "internaldrive"
        case .processStorm: return "square.stack.3d.up.fill"
        case .repoHarnessLeak: return "exclamationmark.arrow.triangle.2.circlepath"
        }
    }
}
