import SwiftUI

struct EventRow: View {
  let event: AnomalyEvent

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      ZStack {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .fill(accent.opacity(0.13))
        Image(systemName: icon)
          .foregroundStyle(accent)
      }
      .frame(width: 34, height: 34)

      VStack(alignment: .leading, spacing: 5) {
        HStack(spacing: 8) {
          Text(event.processName)
            .fontWeight(.semibold)
          StatusPill(text: event.kind.shortName, color: accent)
          Spacer()
          Text(event.date, style: .relative)
            .font(.caption)
            .foregroundStyle(ProcessWatchTheme.textSecondary)
        }

        Text(event.detail)
          .font(.callout)
          .foregroundStyle(ProcessWatchTheme.textSecondary)
          .fixedSize(horizontal: false, vertical: true)

        if !event.processPath.isEmpty {
          Text(event.processPath)
            .font(.system(.caption2, design: .monospaced))
            .foregroundStyle(ProcessWatchTheme.textTertiary)
            .lineLimit(1)
            .truncationMode(.middle)
        }

        HStack(spacing: 14) {
          Label(formatPercent(event.cpuPercent), systemImage: "cpu")
          Label(formatBytes(event.memoryBytes), systemImage: "memorychip")
          Label(formatRate(event.diskWriteBytesPerSecond), systemImage: "arrow.up.doc")
        }
        .font(.caption)
        .monospacedDigit()
        .foregroundStyle(ProcessWatchTheme.textTertiary)
      }
    }
    .padding(.vertical, 10)
  }

  private var accent: Color {
    switch event.kind {
    case .repoHarnessLeak, .processStorm: return ProcessWatchTheme.red
    case .cpu, .memoryGrowth, .diskWrite: return ProcessWatchTheme.amber
    }
  }

  private var icon: String {
    switch event.kind {
    case .cpu: return "cpu"
    case .memoryGrowth: return "memorychip"
    case .diskWrite: return "internaldrive"
    case .processStorm: return "square.stack.3d.up.badge.a"
    case .repoHarnessLeak: return "exclamationmark.triangle.fill"
    }
  }
}
