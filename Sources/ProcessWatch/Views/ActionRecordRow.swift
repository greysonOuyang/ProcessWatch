import SwiftUI

struct ActionRecordRow: View {
  let record: UserActionRecord

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
          Text(record.processName)
            .fontWeight(.semibold)
          StatusPill(text: record.action.rawValue, color: ProcessWatchTheme.blue)
          StatusPill(text: record.outcome.rawValue, color: accent)
          Spacer()
          Text(record.date, style: .relative)
            .font(.caption)
            .foregroundStyle(ProcessWatchTheme.textSecondary)
        }

        Text(record.detail)
          .font(.callout)
          .foregroundStyle(ProcessWatchTheme.textSecondary)
          .fixedSize(horizontal: false, vertical: true)

        if !record.processPath.isEmpty {
          Text(record.processPath)
            .font(.system(.caption2, design: .monospaced))
            .foregroundStyle(ProcessWatchTheme.textTertiary)
            .lineLimit(1)
            .truncationMode(.middle)
        }

        if record.attempted > 0 {
          Text("尝试 \(record.attempted) · 成功 \(record.succeeded) · 失败 \(record.failed)")
            .font(.caption2)
            .monospacedDigit()
            .foregroundStyle(ProcessWatchTheme.textTertiary)
        }
      }
    }
    .padding(.vertical, 10)
  }

  private var accent: Color {
    switch record.outcome {
    case .success: return ProcessWatchTheme.teal
    case .partial: return ProcessWatchTheme.amber
    case .failed: return ProcessWatchTheme.red
    case .informational: return ProcessWatchTheme.blue
    }
  }

  private var icon: String {
    switch record.action {
    case .terminate: return "xmark.circle"
    case .forceQuit: return "bolt.trianglebadge.exclamationmark"
    case .terminateOrphans: return "link.badge.plus"
    case .terminateHighUsage: return "flame"
    case .snooze: return "bell.slash"
    case .whitelist: return "checkmark.shield"
    case .reveal: return "folder"
    case .copyCommand: return "doc.on.doc"
    case .openActivityMonitor: return "waveform.path.ecg"
    case .cleanupScript: return "terminal"
    }
  }
}
