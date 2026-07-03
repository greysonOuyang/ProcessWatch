import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var loginItem: LoginItemService

    var body: some View {
        Form {
            Section("通用") {
                Toggle("允许系统异常通知", isOn: $settings.notificationsEnabled)
                Toggle("登录时启动", isOn: Binding(
                    get: { loginItem.isEnabled },
                    set: { loginItem.setEnabled($0) }
                ))
                if let error = loginItem.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                HStack {
                    Text("采样间隔")
                    Spacer()
                    Stepper("\(Int(settings.samplingInterval)) 秒", value: $settings.samplingInterval, in: 1...30, step: 1)
                        .labelsHidden()
                    Text("\(Int(settings.samplingInterval)) 秒")
                        .monospacedDigit()
                        .frame(width: 50, alignment: .trailing)
                }
                Text("默认 5 秒扫描一次。间隔越短，变化更及时，但监控程序本身开销也会增加。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("进程风暴") {
                settingStepper(
                    title: "同一可执行文件实例数超过",
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
                    title: "repo-harness 孤儿运行超过",
                    value: $settings.repoHarnessOrphanDuration,
                    range: 60...7200,
                    step: 60,
                    suffix: "秒"
                )
                Text("当实例数超过阈值时触发进程风暴；如果其中存在 PPID=1、命令或祖先进程属于 repo-harness，且运行超过指定时间的实例，会额外报告疑似进程泄漏。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("CPU 异常") {
                settingStepper(
                    title: "CPU 超过",
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
                Text("单个多线程进程可能超过 100%，100% 大约代表占满一个 CPU 核心。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("内存增长异常") {
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
                Text("该规则检测单个进程的持续增长；概览页同时展示系统内存压力、Swap、压缩内存和可回收缓存。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("磁盘写入异常") {
                settingStepper(
                    title: "写入速度超过",
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

            Section("应用") {
                Button("退出 ProcessWatch", role: .destructive) {
                    NSApplication.shared.terminate(nil)
                }
                Text("关闭主窗口不会停止监控。要完全结束菜单栏程序，请使用此按钮或按 Command-Q。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("忽略的进程") {
                if settings.ignoredProcessNames.isEmpty {
                    Text("暂无。可在进程页面的进程组菜单中添加。")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(settings.ignoredProcessNames.sorted(), id: \.self) { name in
                        HStack {
                            Text(name)
                            Spacer()
                            Button("移除") { settings.unignore(name) }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(.horizontal, 12)
    }

    private func settingStepper(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        suffix: String
    ) -> some View {
        HStack {
            Text(title)
            Spacer()
            Stepper("", value: value, in: range, step: step)
                .labelsHidden()
            Text("\(value.wrappedValue, specifier: "%.0f") \(suffix)")
                .monospacedDigit()
                .frame(width: 100, alignment: .trailing)
        }
    }
}
