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

    @State private var searchText = ""
    @State private var sortMode: SortMode = .cpu
    @State private var onlyAnomalies = false
    @State private var expandedGroups: Set<String> = []
    @State private var terminationTarget: ProcessSnapshot?
    @State private var actionMessage: String?

    private var displayedGroups: [ProcessGroupSnapshot] {
        let matchingProcesses = model.processes.filter { $0.matches(searchText: searchText) }
        let filtered = ProcessGroupSnapshot.grouped(matchingProcesses).filter { group in
            !onlyAnomalies || !model.anomalyKinds(for: group).isEmpty
        }

        return filtered.sorted { lhs, rhs in
            switch sortMode {
            case .cpu:
                return lhs.cpuPercent > rhs.cpuPercent
            case .memory:
                return lhs.memoryBytes > rhs.memoryBytes
            case .diskWrite:
                return lhs.diskWriteBytesPerSecond > rhs.diskWriteBytesPerSecond
            case .instances:
                return lhs.instanceCount > rhs.instanceCount
            case .orphans:
                return lhs.orphanCount > rhs.orphanCount
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("进程")
                        .font(.largeTitle.bold())
                    Text("同一可执行文件先聚合，展开后查看每个 PID 的完整身份")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("仅异常", isOn: $onlyAnomalies)
                    .toggleStyle(.checkbox)
                Picker("排序", selection: $sortMode) {
                    ForEach(SortMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 130)
            }
            .padding(.horizontal, 22)
            .padding(.top, 20)
            .padding(.bottom, 12)

            HStack {
                TextField("搜索名称、PID、PPID、命令、目录、父进程或归属", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                Text("\(displayedGroups.count) 组 · \(displayedGroups.reduce(0) { $0 + $1.instanceCount }) 个实例")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 12)

            HStack(spacing: 12) {
                Text("进程组").frame(maxWidth: .infinity, alignment: .leading)
                Text("CPU 合计").frame(width: 82, alignment: .trailing)
                Text("内存合计").frame(width: 100, alignment: .trailing)
                Text("孤儿").frame(width: 58, alignment: .trailing)
                Text("最长运行").frame(width: 112, alignment: .trailing)
                Text("").frame(width: 30)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 22)
            .padding(.vertical, 7)
            .background(Color.secondary.opacity(0.06))

            List {
                ForEach(displayedGroups) { group in
                    DisclosureGroup(isExpanded: expansionBinding(for: group.id)) {
                        VStack(spacing: 8) {
                            ForEach(group.processes) { process in
                                processIdentityCard(process)
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.leading, 24)
                    } label: {
                        groupRow(group)
                    }
                }
            }
            .listStyle(.inset)
        }
        .alert("结束进程？", isPresented: Binding(
            get: { terminationTarget != nil },
            set: { if !$0 { terminationTarget = nil } }
        )) {
            Button("取消", role: .cancel) { terminationTarget = nil }
            Button("发送结束信号", role: .destructive) {
                if let process = terminationTarget {
                    let succeeded = ProcessActionService.terminate(process)
                    actionMessage = succeeded
                        ? "已向 \(process.name)（PID \(process.pid)）发送 SIGTERM。"
                        : "无法结束 \(process.name)（PID \(process.pid)），可能没有权限。"
                }
                terminationTarget = nil
            }
        } message: {
            Text("将向 PID \(terminationTarget?.pid ?? 0) 发送 SIGTERM，不会强制杀死系统进程。")
        }
        .alert("操作结果", isPresented: Binding(
            get: { actionMessage != nil },
            set: { if !$0 { actionMessage = nil } }
        )) {
            Button("好") { actionMessage = nil }
        } message: {
            Text(actionMessage ?? "")
        }
    }

    private func expansionBinding(for id: String) -> Binding<Bool> {
        Binding(
            get: { expandedGroups.contains(id) },
            set: { isExpanded in
                if isExpanded {
                    expandedGroups.insert(id)
                } else {
                    expandedGroups.remove(id)
                }
            }
        )
    }

    private func groupRow(_ group: ProcessGroupSnapshot) -> some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: model.anomalyKinds(for: group).isEmpty ? "square.stack.3d.up" : "exclamationmark.triangle.fill")
                    .foregroundStyle(model.anomalyKinds(for: group).isEmpty ? Color(nsColor: .secondaryLabelColor) : Color.orange)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("\(group.name) × \(group.instanceCount)")
                            .fontWeight(.semibold)
                        if group.orphanCount > 0 {
                            badge("孤儿 \(group.orphanCount)", systemImage: "link.badge.plus", emphasized: group.orphanCount > Int(settings.processStormInstanceThreshold))
                        }
                        if let affiliation = group.affiliationSummary {
                            badge(affiliation, systemImage: "shippingbox", emphasized: false)
                        }
                        if settings.isIgnored(group.name) {
                            badge("已忽略", systemImage: "bell.slash", emphasized: false)
                        }
                    }

                    Text(group.path.isEmpty ? "无法读取可执行文件路径" : group.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Text("写入 \(formatRate(group.diskWriteBytesPerSecond)) · 读取 \(formatRate(group.diskReadBytesPerSecond))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            value(formatPercent(group.cpuPercent), width: 82)
            value(formatBytes(group.memoryBytes), width: 100)
            value("\(group.orphanCount)", width: 58)
            value(formatDuration(group.longestRuntime), width: 112)

            Menu {
                if settings.isIgnored(group.name) {
                    Button("取消忽略该类进程") { settings.unignore(group.name) }
                } else {
                    Button("忽略该类进程") { settings.ignore(group.name) }
                }
                if let representative = group.representative {
                    Button("在 Finder 中显示可执行文件") {
                        ProcessActionService.reveal(representative)
                    }
                    .disabled(representative.path.isEmpty)
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .frame(width: 30)
        }
        .padding(.vertical, 7)
    }

    private func processIdentityCard(_ process: ProcessSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                Image(systemName: model.anomalyKinds(for: process).isEmpty ? "app.dashed" : "exclamationmark.triangle.fill")
                    .foregroundStyle(model.anomalyKinds(for: process).isEmpty ? Color(nsColor: .secondaryLabelColor) : Color.orange)
                    .frame(width: 18)

                Text("PID \(process.pid)")
                    .fontWeight(.semibold)
                    .monospacedDigit()
                Text("PPID \(process.ppid)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Text("父进程：\(process.parentName)")
                    .foregroundStyle(.secondary)

                if process.isOrphan {
                    badge("孤儿进程", systemImage: "link.badge.plus", emphasized: true)
                }
                if process.affiliation != .none {
                    badge(process.affiliation.rawValue, systemImage: "shippingbox", emphasized: false)
                }

                Spacer()
                compactValue("CPU", formatPercent(process.cpuPercent))
                compactValue("内存", formatBytes(process.memoryBytes))
                compactValue("写入", formatRate(process.diskWriteBytesPerSecond))

                Menu {
                    Button("在 Finder 中显示") { ProcessActionService.reveal(process) }
                        .disabled(process.path.isEmpty)
                    Divider()
                    Button("结束进程…", role: .destructive) { terminationTarget = process }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
            }

            identityLine("完整命令", value: process.commandLine.isEmpty ? "无法读取" : process.commandLine, monospaced: true)
            identityLine("工作目录", value: process.workingDirectory.isEmpty ? "无法读取" : process.workingDirectory, monospaced: true)

            HStack(spacing: 18) {
                if let startTime = process.startTime {
                    LabeledContent("启动时间") {
                        Text(startTime, format: .dateTime.year().month().day().hour().minute().second())
                            .monospacedDigit()
                    }
                } else {
                    LabeledContent("启动时间", value: "无法读取")
                }
                LabeledContent("已运行", value: formatDuration(process.runtime))
                LabeledContent("读取", value: formatRate(process.diskReadBytesPerSecond))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }

    private func identityLine(_ title: String, value: String, monospaced: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)
            Text(value)
                .font(monospaced ? .system(.caption, design: .monospaced) : .caption)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func badge(_ text: String, systemImage: String, emphasized: Bool) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(emphasized ? Color.orange.opacity(0.18) : Color.secondary.opacity(0.10), in: Capsule())
            .foregroundStyle(emphasized ? Color.orange : Color.secondary)
    }

    private func value(_ text: String, width: CGFloat) -> some View {
        Text(text)
            .monospacedDigit()
            .frame(width: width, alignment: .trailing)
    }

    private func compactValue(_ title: String, _ value: String) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
                .monospacedDigit()
        }
        .frame(width: 78, alignment: .trailing)
    }
}
