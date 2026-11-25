import AppKit
import SwiftUI

struct MainView: View {
  @EnvironmentObject private var model: AppModel

  var body: some View {
    HStack(spacing: 0) {
      sidebar

      Rectangle()
        .fill(ProcessWatchTheme.border)
        .frame(width: 1)

      content
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .background(ProcessWatchTheme.windowBackground.ignoresSafeArea())
    .preferredColorScheme(.dark)
    .frame(minWidth: 1260, minHeight: 760)
  }

  // MARK: - Sidebar

  private var sidebar: some View {
    VStack(alignment: .leading, spacing: 0) {
      brand
        .padding(.top, 44) // clear the traffic-light buttons
        .padding(.bottom, 18)

      navSection

      Spacer(minLength: 12)

      monitoringStatus
        .padding(.bottom, 10)

      Rectangle()
        .fill(ProcessWatchTheme.border)
        .frame(height: 1)
        .padding(.bottom, 10)

      bottomControls
        .padding(.bottom, 14)
    }
    .padding(.horizontal, 12)
    .frame(width: ProcessWatchLayout.sidebarWidth)
    .frame(maxHeight: .infinity)
    .background(Color.black.opacity(0.18))
  }

  private var brand: some View {
    HStack(spacing: 11) {
      ZStack {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .fill(
            LinearGradient(
              colors: [ProcessWatchTheme.amber.opacity(0.85), ProcessWatchTheme.amber.opacity(0.55)],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
          .shadow(color: ProcessWatchTheme.amber.opacity(0.35), radius: 8, y: 2)
        Image(systemName: "waveform.path.ecg")
          .font(.callout.weight(.bold))
          .foregroundStyle(.black.opacity(0.85))
      }
      .frame(width: 36, height: 36)

      VStack(alignment: .leading, spacing: 3) {
        Text("ProcessWatch")
          .font(.callout.weight(.bold))
          .foregroundStyle(ProcessWatchTheme.textPrimary)
        HStack(spacing: 5) {
          Circle()
            .fill(model.isPaused ? ProcessWatchTheme.amber : ProcessWatchTheme.teal)
            .frame(width: 6, height: 6)
            .shadow(
              color: (model.isPaused ? ProcessWatchTheme.amber : ProcessWatchTheme.teal).opacity(0.7),
              radius: 3
            )
          Text(model.isPaused ? "监控已暂停" : "正在监控")
            .font(.caption2)
            .foregroundStyle(ProcessWatchTheme.textSecondary)
        }
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 6)
  }

  private var navSection: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("导航")
        .font(.caption2.weight(.bold))
        .tracking(1.2)
        .foregroundStyle(ProcessWatchTheme.textTertiary)
        .padding(.horizontal, 10)
        .padding(.bottom, 4)

      ForEach(Array(AppSection.allCases.enumerated()), id: \.element.id) { index, section in
        SidebarNavButton(
          section: section,
          isSelected: model.selectedSection == section,
          badgeCount: section == .alerts ? model.activeAnomalyCount : 0,
          shortcutNumber: index + 1
        ) {
          model.selectedSection = section
        }
      }
    }
  }

  private var monitoringStatus: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 6) {
        Image(systemName: "timer")
          .font(.caption2)
          .foregroundStyle(ProcessWatchTheme.textTertiary)
        Text("每 \(Int(model.settings.samplingInterval)) 秒采样")
          .font(.caption2)
          .foregroundStyle(ProcessWatchTheme.textSecondary)
      }
      if let lastSampleAt = model.lastSampleAt {
        HStack(spacing: 6) {
          Image(systemName: "clock.arrow.circlepath")
            .font(.caption2)
            .foregroundStyle(ProcessWatchTheme.textTertiary)
          Text("更新于 \(lastSampleAt.formatted(date: .omitted, time: .standard))")
            .font(.caption2)
            .monospacedDigit()
            .foregroundStyle(ProcessWatchTheme.textSecondary)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(
      ProcessWatchTheme.surfaceSoft,
      in: RoundedRectangle(cornerRadius: ProcessWatchLayout.compactRadius, style: .continuous)
    )
    .overlay(
      RoundedRectangle(cornerRadius: ProcessWatchLayout.compactRadius, style: .continuous)
        .stroke(ProcessWatchTheme.border, lineWidth: 1)
    )
  }

  private var bottomControls: some View {
    HStack(spacing: 8) {
      Button {
        model.togglePaused()
      } label: {
        Image(systemName: model.isPaused ? "play.fill" : "pause.fill")
          .frame(width: 14)
      }
      .buttonStyle(ProcessWatchButtonStyle(kind: .subtle))
      .help(model.isPaused ? "继续监控" : "暂停监控")

      Button {
        model.selectedSection = .alerts
      } label: {
        ZStack(alignment: .topTrailing) {
          Image(systemName: "exclamationmark.triangle.fill")
            .foregroundStyle(model.activeAnomalyCount > 0 ? ProcessWatchTheme.red : ProcessWatchTheme.textSecondary)
            .frame(width: 14)
          if model.activeAnomalyCount > 0 {
            Circle()
              .fill(ProcessWatchTheme.red)
              .frame(width: 7, height: 7)
              .offset(x: 5, y: -4)
          }
        }
      }
      .buttonStyle(ProcessWatchButtonStyle(kind: .subtle))
      .help("查看活动异常")

      Spacer(minLength: 0)

      Menu {
        Button("关于 ProcessWatch") { ApplicationInfo.showAboutPanel() }
        Button("打开本地数据目录") { ApplicationInfo.openDataDirectory() }
        Button("复制诊断信息") { _ = ApplicationInfo.copyDiagnostics() }
        Divider()
        Button("退出 ProcessWatch", role: .destructive) {
          NSApplication.shared.terminate(nil)
        }
      } label: {
        Image(systemName: "ellipsis")
          .frame(width: 14)
      }
      .menuStyle(.borderlessButton)
      .buttonStyle(ProcessWatchButtonStyle(kind: .subtle))
      .frame(width: 38)
    }
  }

  // MARK: - Content

  @ViewBuilder
  private var content: some View {
    ZStack {
      switch model.selectedSection {
      case .overview:
        OverviewView()
      case .processes:
        ProcessListView(settings: model.settings)
      case .alerts:
        AlertsView()
      case .settings:
        SettingsView(settings: model.settings, loginItem: model.loginItem)
      }
    }
    .id(model.selectedSection)
    .transition(.opacity.combined(with: .scale(scale: 0.992, anchor: .top)))
    .animation(.easeOut(duration: 0.18), value: model.selectedSection)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

// MARK: - Sidebar navigation button

private struct SidebarNavButton: View {
  let section: AppSection
  let isSelected: Bool
  let badgeCount: Int
  let shortcutNumber: Int
  let action: () -> Void

  @State private var isHovering = false

  var body: some View {
    Button(action: action) {
      HStack(spacing: 10) {
        // Selection indicator bar
        RoundedRectangle(cornerRadius: 2, style: .continuous)
          .fill(isSelected ? ProcessWatchTheme.accent : Color.clear)
          .frame(width: 3, height: 18)
          .shadow(color: isSelected ? ProcessWatchTheme.accent.opacity(0.6) : .clear, radius: 3)

        Image(systemName: section.systemImage)
          .font(.callout.weight(.medium))
          .frame(width: 20)
          .foregroundStyle(
            isSelected ? ProcessWatchTheme.accent : ProcessWatchTheme.textSecondary
          )

        Text(section.rawValue)
          .font(.callout.weight(isSelected ? .semibold : .regular))
          .foregroundStyle(
            isSelected ? ProcessWatchTheme.textPrimary : ProcessWatchTheme.textSecondary
          )

        Spacer(minLength: 4)

        if badgeCount > 0 {
          Text("\(badgeCount)")
            .font(.caption2.weight(.bold))
            .monospacedDigit()
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(ProcessWatchTheme.red, in: Capsule())
            .foregroundStyle(.white)
            .shadow(color: ProcessWatchTheme.red.opacity(0.5), radius: 4)
        }
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 9)
      .background(
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .fill(
            isSelected
              ? ProcessWatchTheme.surfaceSelected
              : (isHovering ? ProcessWatchTheme.surfaceHover : Color.clear)
          )
      )
      .overlay(
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .stroke(
            isSelected ? ProcessWatchTheme.accent.opacity(0.25) : Color.clear,
            lineWidth: 1
          )
      )
      .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    .buttonStyle(.plain)
    .keyboardShortcut(
      KeyboardShortcut(KeyEquivalent(Character("\(shortcutNumber)")), modifiers: .command)
    )
    .onHover { isHovering = $0 }
    .animation(.easeOut(duration: 0.15), value: isHovering)
    .animation(.easeOut(duration: 0.15), value: isSelected)
    .help("⌘\(shortcutNumber)")
  }
}
