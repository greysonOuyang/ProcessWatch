import AppKit
import SwiftUI

struct MainView: View {
  @EnvironmentObject private var model: AppModel

  var body: some View {
    ZStack {
      ProcessWatchTheme.windowBackground
        .ignoresSafeArea()

      VStack(spacing: 0) {
        topBar
        Rectangle()
          .fill(ProcessWatchTheme.border)
          .frame(height: 1)
        content
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .preferredColorScheme(.dark)
    .frame(minWidth: 1180, minHeight: 720)
  }

  private var topBar: some View {
    HStack(spacing: 14) {
      // The traffic-light reserve is isolated to the title bar. Page content keeps a consistent 20 pt inset.
      Color.clear.frame(width: 48, height: 1)

      brand

      Spacer(minLength: 12)
      navigation
      Spacer(minLength: 12)
      windowActions
    }
    .padding(.horizontal, ProcessWatchLayout.pageHorizontal)
    .frame(height: 68)
    .background(Color.black.opacity(0.10))
  }

  private var brand: some View {
    HStack(spacing: 10) {
      ZStack {
        RoundedRectangle(cornerRadius: 11, style: .continuous)
          .fill(ProcessWatchTheme.amber.opacity(0.15))
          .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
              .stroke(ProcessWatchTheme.amber.opacity(0.20), lineWidth: 1)
          )
        Image(systemName: "waveform.path.ecg")
          .font(.title3.weight(.semibold))
          .foregroundStyle(ProcessWatchTheme.amber)
      }
      .frame(width: 42, height: 42)

      VStack(alignment: .leading, spacing: 2) {
        Text("ProcessWatch")
          .font(.headline)
          .foregroundStyle(ProcessWatchTheme.textPrimary)
        HStack(spacing: 5) {
          Circle()
            .fill(model.isPaused ? ProcessWatchTheme.amber : ProcessWatchTheme.teal)
            .frame(width: 6, height: 6)
          Text(model.isPaused ? "监控已暂停" : "正在监控")
        }
        .font(.caption2)
        .foregroundStyle(ProcessWatchTheme.textSecondary)
      }
    }
  }

  private var navigation: some View {
    HStack(spacing: 3) {
      ForEach(AppSection.allCases) { section in
        Button {
          model.selectedSection = section
        } label: {
          HStack(spacing: 7) {
            Image(systemName: section.systemImage)
              .font(.caption)
            Text(section.rawValue)
            if section == .alerts && model.activeAnomalyCount > 0 {
              Text("\(model.activeAnomalyCount)")
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(ProcessWatchTheme.red, in: Capsule())
                .foregroundStyle(.white)
            }
          }
          .font(.callout.weight(model.selectedSection == section ? .semibold : .regular))
          .foregroundStyle(
            model.selectedSection == section
              ? ProcessWatchTheme.textPrimary : ProcessWatchTheme.textSecondary
          )
          .padding(.horizontal, 15)
          .padding(.vertical, 9)
          .background(
            model.selectedSection == section
              ? ProcessWatchTheme.surfaceSelected : Color.clear,
            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
          )
          .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
              .stroke(
                model.selectedSection == section
                  ? ProcessWatchTheme.amber.opacity(0.20) : Color.clear,
                lineWidth: 1
              )
          )
        }
        .buttonStyle(.plain)
      }
    }
    .padding(4)
    .background(
      Color.black.opacity(0.20),
      in: RoundedRectangle(cornerRadius: 12, style: .continuous)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .stroke(ProcessWatchTheme.border, lineWidth: 1)
    )
  }

  private var windowActions: some View {
    HStack(spacing: 8) {
      if model.activeAnomalyCount > 0 {
        Button {
          model.selectedSection = .alerts
        } label: {
          Label("\(model.activeAnomalyCount)", systemImage: "exclamationmark.triangle.fill")
            .foregroundStyle(ProcessWatchTheme.red)
        }
        .buttonStyle(ProcessWatchButtonStyle(kind: .subtle))
        .help("查看活动异常")
      }

      Button {
        model.togglePaused()
      } label: {
        Image(systemName: model.isPaused ? "play.fill" : "pause.fill")
          .frame(width: 16)
      }
      .buttonStyle(ProcessWatchButtonStyle(kind: .subtle))
      .help(model.isPaused ? "继续监控" : "暂停监控")

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
          .frame(width: 16)
      }
      .menuStyle(.borderlessButton)
      .buttonStyle(ProcessWatchButtonStyle(kind: .subtle))
      .frame(width: 42)
    }
  }

  @ViewBuilder
  private var content: some View {
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
}
