import SwiftUI

struct SystemIncidentCard: View {
  @EnvironmentObject private var model: AppModel

  var body: some View {
    if let incident = model.activeIncident {
      activeCard(incident)
    } else if let incident = model.recentIncident {
      resolvedCard(incident)
    }
  }

  private func activeCard(_ incident: ActiveSystemIncident) -> some View {
    DashboardCard(padding: 0, elevated: true) {
      VStack(spacing: 0) {
        HStack(alignment: .top, spacing: 14) {
          ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
              .fill(ProcessWatchTheme.red.opacity(0.16))
            Image(systemName: "flame.fill")
              .font(.title2)
              .foregroundStyle(ProcessWatchTheme.red)
          }
          .frame(width: 48, height: 48)

          VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
              Text("系统检测到资源异常")
                .font(.title3.weight(.semibold))
              StatusPill(text: "已持续 \(formatCompactDuration(incident.duration()))", color: ProcessWatchTheme.red)
              StatusPill(text: "热状态 \(model.system.thermalState.rawValue)", color: thermalColor)
            }
            Text(incident.reasons.joined(separator: " · "))
              .font(.callout)
              .foregroundStyle(ProcessWatchTheme.textSecondary)
              .fixedSize(horizontal: false, vertical: true)
          }

          Spacer(minLength: 12)

          Button(incident.suspects.isEmpty ? "查看详情" : "查看可处理项") {
            model.selectedSection = .alerts
          }
          .buttonStyle(ProcessWatchButtonStyle(kind: .primary))
        }
        .padding(16)
        .background(
          LinearGradient(
            colors: [ProcessWatchTheme.red.opacity(0.13), Color.clear],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )

        if !incident.suspects.isEmpty {
          Rectangle().fill(ProcessWatchTheme.border).frame(height: 1)
          VStack(spacing: 0) {
            ForEach(Array(incident.suspects.prefix(3).enumerated()), id: \.element.id) { index, suspect in
              HStack(spacing: 10) {
                Text("\(index + 1)")
                  .font(.caption.weight(.bold))
                  .foregroundStyle(ProcessWatchTheme.textTertiary)
                  .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                  Text("\(suspect.name) × \(suspect.instanceCount)")
                    .font(.callout.weight(.semibold))
                  Text(suspect.path.isEmpty ? "路径不可用" : suspect.path)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(ProcessWatchTheme.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                }
                Spacer()
                StatusPill(text: "证据 \(suspect.score)", color: scoreColor(suspect.score))
                StatusPill(text: "可操作 \(suspect.actionableProcessCount)", color: ProcessWatchTheme.teal)
                Text(formatPercent(suspect.cpuPercent))
                  .font(.system(.callout, design: .monospaced).weight(.semibold))
                  .foregroundStyle(ProcessWatchTheme.red)
                  .frame(width: 68, alignment: .trailing)
                Text(formatBytes(suspect.memoryBytes))
                  .font(.system(.caption, design: .monospaced))
                  .foregroundStyle(ProcessWatchTheme.textSecondary)
                  .frame(width: 78, alignment: .trailing)
              }
              .padding(.horizontal, 16)
              .padding(.vertical, 9)

              if index < min(incident.suspects.count, 3) - 1 {
                Rectangle().fill(ProcessWatchTheme.border).frame(height: 1)
              }
            }
          }
        } else {
          Rectangle().fill(ProcessWatchTheme.border).frame(height: 1)
          Label(
            "检测到系统级异常，但当前没有通过所有者与身份校验的可操作进程。ProcessWatch 不会建议终止系统、root 或身份未知的进程。",
            systemImage: "lock.shield"
          )
          .font(.caption)
          .foregroundStyle(ProcessWatchTheme.textSecondary)
          .padding(16)
          .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
    }
  }

  private func resolvedCard(_ incident: SystemIncidentRecord) -> some View {
    DashboardCard(padding: 14) {
      HStack(spacing: 12) {
        Image(systemName: "checkmark.circle.fill")
          .font(.title2)
          .foregroundStyle(ProcessWatchTheme.teal)
        VStack(alignment: .leading, spacing: 3) {
          Text("最近一次系统异常已恢复")
            .font(.headline)
          Text(
            "持续 \(formatCompactDuration(incident.duration)) · 峰值 CPU \(formatPercent(incident.peakCPUPercent)) · 最严重热状态 \(incident.worstThermalState.rawValue)"
          )
          .font(.caption)
          .foregroundStyle(ProcessWatchTheme.textSecondary)
        }
        Spacer()
        if let suspect = incident.suspects.first {
          Text("主要可操作对象：\(suspect.name)")
            .font(.caption.weight(.medium))
            .foregroundStyle(ProcessWatchTheme.textSecondary)
        }
        Text(incident.endedAt.formatted(date: .abbreviated, time: .shortened))
          .font(.caption2)
          .foregroundStyle(ProcessWatchTheme.textTertiary)
      }
    }
  }

  private var thermalColor: Color {
    switch model.system.thermalState {
    case .critical, .serious: return ProcessWatchTheme.red
    case .fair: return ProcessWatchTheme.amber
    default: return ProcessWatchTheme.teal
    }
  }

  private func scoreColor(_ score: Int) -> Color {
    if score >= 70 { return ProcessWatchTheme.red }
    if score >= 40 { return ProcessWatchTheme.amber }
    return ProcessWatchTheme.blue
  }
}
