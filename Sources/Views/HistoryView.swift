import SwiftUI

struct HistoryView: View {
    @ObservedObject var history: HistoryStore
    @State private var confirmClear = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("异常历史")
                        .font(.largeTitle.bold())
                    Text("最多保留最近 200 条记录")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("清空历史", role: .destructive) {
                    confirmClear = true
                }
                .disabled(history.events.isEmpty)
            }
            .padding(22)

            if history.events.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.shield")
                        .font(.system(size: 38))
                        .foregroundStyle(.secondary)
                    Text("暂无异常记录")
                        .font(.headline)
                    Text("持续超出阈值的进程会记录在这里。")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(history.events) { event in
                    EventRow(event: event)
                }
                .listStyle(.inset)
            }
        }
        .alert("清空全部历史？", isPresented: $confirmClear) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) { history.clear() }
        } message: {
            Text("该操作无法撤销。")
        }
    }
}
