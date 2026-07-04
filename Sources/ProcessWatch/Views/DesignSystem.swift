import SwiftUI

enum ProcessWatchLayout {
  static let pageHorizontal: CGFloat = 20
  static let pageVertical: CGFloat = 18
  static let sectionGap: CGFloat = 14
  static let cardGap: CGFloat = 12
  static let cardRadius: CGFloat = 14
  static let compactRadius: CGFloat = 10
  static let detailPanelWidth: CGFloat = 390
}

enum ProcessWatchTheme {
  static let backgroundTop = Color(red: 0.075, green: 0.068, blue: 0.058)
  static let backgroundMiddle = Color(red: 0.047, green: 0.047, blue: 0.050)
  static let backgroundBottom = Color(red: 0.029, green: 0.030, blue: 0.034)
  static let surface = Color(red: 0.105, green: 0.100, blue: 0.092)
  static let surfaceRaised = Color(red: 0.132, green: 0.124, blue: 0.111)
  static let surfaceSoft = Color.white.opacity(0.045)
  static let surfaceSelected = Color(red: 0.31, green: 0.225, blue: 0.125).opacity(0.42)
  static let border = Color.white.opacity(0.095)
  static let borderStrong = Color.white.opacity(0.16)
  static let textPrimary = Color.white.opacity(0.94)
  static let textSecondary = Color.white.opacity(0.64)
  static let textTertiary = Color.white.opacity(0.42)
  static let amber = Color(red: 0.94, green: 0.64, blue: 0.28)
  static let teal = Color(red: 0.29, green: 0.77, blue: 0.61)
  static let blue = Color(red: 0.31, green: 0.64, blue: 0.94)
  static let red = Color(red: 0.92, green: 0.34, blue: 0.32)

  static var windowBackground: some View {
    LinearGradient(
      colors: [backgroundTop, backgroundMiddle, backgroundBottom],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }

  static var popoverBackground: some View {
    LinearGradient(
      colors: [backgroundTop.opacity(0.98), backgroundBottom],
      startPoint: .top,
      endPoint: .bottom
    )
  }
}

struct DashboardCard<Content: View>: View {
  private let content: Content
  private let padding: CGFloat
  private let cornerRadius: CGFloat
  private let elevated: Bool

  init(
    padding: CGFloat = 16,
    cornerRadius: CGFloat = ProcessWatchLayout.cardRadius,
    elevated: Bool = false,
    @ViewBuilder content: () -> Content
  ) {
    self.padding = padding
    self.cornerRadius = cornerRadius
    self.elevated = elevated
    self.content = content()
  }

  var body: some View {
    content
      .padding(padding)
      .background(
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .fill(elevated ? ProcessWatchTheme.surfaceRaised : ProcessWatchTheme.surface)
      )
      .overlay(
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .stroke(elevated ? ProcessWatchTheme.borderStrong : ProcessWatchTheme.border, lineWidth: 1)
      )
      .shadow(color: .black.opacity(elevated ? 0.24 : 0.12), radius: elevated ? 18 : 10, y: elevated ? 10 : 5)
  }
}

struct StatusPill: View {
  let text: String
  let color: Color

  var body: some View {
    Text(text)
      .font(.caption2.weight(.semibold))
      .lineLimit(1)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .foregroundStyle(color)
      .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 6, style: .continuous)
          .stroke(color.opacity(0.18), lineWidth: 1)
      )
  }
}

struct SectionHeading: View {
  let title: String
  let subtitle: String

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.title2.weight(.semibold))
        .foregroundStyle(ProcessWatchTheme.textPrimary)
      Text(subtitle)
        .font(.caption)
        .foregroundStyle(ProcessWatchTheme.textSecondary)
    }
  }
}

struct MetricTile: View {
  let title: String
  let value: String
  let accent: Color
  var subtitle: String? = nil

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(title.uppercased())
        .font(.caption2.weight(.bold))
        .tracking(0.9)
        .foregroundStyle(ProcessWatchTheme.textTertiary)
      Text(value)
        .font(.system(.headline, design: .rounded).weight(.semibold))
        .monospacedDigit()
        .foregroundStyle(accent)
        .lineLimit(1)
        .minimumScaleFactor(0.72)
      if let subtitle {
        Text(subtitle)
          .font(.caption2)
          .foregroundStyle(ProcessWatchTheme.textSecondary)
          .lineLimit(1)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(10)
    .background(
      ProcessWatchTheme.surfaceSoft,
      in: RoundedRectangle(cornerRadius: ProcessWatchLayout.compactRadius, style: .continuous)
    )
    .overlay(
      RoundedRectangle(cornerRadius: ProcessWatchLayout.compactRadius, style: .continuous)
        .stroke(ProcessWatchTheme.border, lineWidth: 1)
    )
  }
}

struct Sparkline: View {
  let points: [MetricPoint]
  let color: Color
  var fill = true

  var body: some View {
    GeometryReader { proxy in
      let values = points.map(\.value)
      let minValue = values.min() ?? 0
      let maxValue = values.max() ?? 1
      let range = max(maxValue - minValue, max(abs(maxValue), 1) * 0.08)
      let path = linePath(in: proxy.size, minValue: minValue, range: range)

      ZStack {
        if fill, points.count > 1 {
          areaPath(in: proxy.size, minValue: minValue, range: range)
            .fill(
              LinearGradient(
                colors: [color.opacity(0.24), color.opacity(0.01)],
                startPoint: .top,
                endPoint: .bottom
              )
            )
        }

        path
          .stroke(color, style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round))
          .shadow(color: color.opacity(0.30), radius: 4)
      }
    }
    .accessibilityHidden(true)
  }

  private func linePath(in size: CGSize, minValue: Double, range: Double) -> Path {
    var path = Path()
    guard points.count > 1 else { return path }
    for (index, point) in points.enumerated() {
      let x = size.width * CGFloat(index) / CGFloat(max(points.count - 1, 1))
      let normalized = (point.value - minValue) / range
      let y = size.height - size.height * CGFloat(normalized)
      if index == 0 {
        path.move(to: CGPoint(x: x, y: y))
      } else {
        path.addLine(to: CGPoint(x: x, y: y))
      }
    }
    return path
  }

  private func areaPath(in size: CGSize, minValue: Double, range: Double) -> Path {
    var path = linePath(in: size, minValue: minValue, range: range)
    guard points.count > 1 else { return path }
    path.addLine(to: CGPoint(x: size.width, y: size.height))
    path.addLine(to: CGPoint(x: 0, y: size.height))
    path.closeSubpath()
    return path
  }
}

struct DashboardMetricCard: View {
  let title: String
  let value: String
  let detail: String
  let footer: String
  let systemImage: String
  let accent: Color
  let statusText: String
  let statusColor: Color
  let points: [MetricPoint]

  var body: some View {
    DashboardCard(padding: 14) {
      VStack(alignment: .leading, spacing: 10) {
        HStack(spacing: 7) {
          Image(systemName: systemImage)
            .foregroundStyle(accent)
          Text(title.uppercased())
            .font(.caption.weight(.bold))
            .tracking(1.1)
            .foregroundStyle(accent)
          Spacer(minLength: 4)
          StatusPill(text: statusText, color: statusColor)
        }

        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Text(value)
            .font(.system(size: 30, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.68)
          Text(detail)
            .font(.caption)
            .foregroundStyle(ProcessWatchTheme.textSecondary)
            .lineLimit(2)
          Spacer(minLength: 0)
        }

        Sparkline(points: points, color: accent)
          .frame(height: 46)

        Text(footer)
          .font(.caption)
          .monospacedDigit()
          .foregroundStyle(ProcessWatchTheme.textSecondary)
          .lineLimit(1)
          .minimumScaleFactor(0.72)
      }
    }
    .frame(minHeight: 150)
  }
}

enum ProcessWatchButtonKind {
  case primary
  case secondary
  case danger
  case subtle
}

struct ProcessWatchButtonStyle: ButtonStyle {
  let kind: ProcessWatchButtonKind
  @Environment(\.isEnabled) private var isEnabled

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.callout.weight(.medium))
      .foregroundStyle(foreground)
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(background.opacity(configuration.isPressed ? 0.72 : 1))
      .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 9, style: .continuous)
          .stroke(border, lineWidth: 1)
      )
      .opacity(isEnabled ? 1 : 0.45)
  }

  private var background: Color {
    switch kind {
    case .primary: return ProcessWatchTheme.amber.opacity(0.22)
    case .secondary: return ProcessWatchTheme.surfaceRaised
    case .danger: return ProcessWatchTheme.red.opacity(0.72)
    case .subtle: return ProcessWatchTheme.surfaceSoft
    }
  }

  private var foreground: Color {
    switch kind {
    case .primary: return ProcessWatchTheme.amber
    case .secondary, .subtle: return ProcessWatchTheme.textPrimary
    case .danger: return .white
    }
  }

  private var border: Color {
    switch kind {
    case .primary: return ProcessWatchTheme.amber.opacity(0.28)
    case .secondary, .subtle: return ProcessWatchTheme.border
    case .danger: return ProcessWatchTheme.red.opacity(0.35)
    }
  }
}

extension View {
  func processWatchPanelBackground(cornerRadius: CGFloat = ProcessWatchLayout.cardRadius) -> some View {
    background(
      RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        .fill(ProcessWatchTheme.surface)
    )
    .overlay(
      RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        .stroke(ProcessWatchTheme.border, lineWidth: 1)
    )
  }
}
