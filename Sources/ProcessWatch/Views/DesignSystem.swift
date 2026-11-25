import SwiftUI

enum ProcessWatchLayout {
  static let pageHorizontal: CGFloat = 26
  static let pageVertical: CGFloat = 20
  static let sectionGap: CGFloat = 16
  static let cardGap: CGFloat = 14
  static let panelGap: CGFloat = 16
  static let cardRadius: CGFloat = 16
  static let compactRadius: CGFloat = 10
  static let detailPanelWidth: CGFloat = 420
  static let compactDetailPanelWidth: CGFloat = 360
  static let sidebarWidth: CGFloat = 216
}

enum ProcessWatchTheme {
  // Cool graphite base — deeper and more neutral than the old warm brown palette.
  static let backgroundTop = Color(red: 0.078, green: 0.082, blue: 0.098)
  static let backgroundMiddle = Color(red: 0.052, green: 0.056, blue: 0.070)
  static let backgroundBottom = Color(red: 0.032, green: 0.035, blue: 0.046)
  static let surface = Color(red: 0.108, green: 0.114, blue: 0.135)
  static let surfaceRaised = Color(red: 0.138, green: 0.145, blue: 0.168)
  static let surfaceSoft = Color.white.opacity(0.05)
  static let surfaceHover = Color.white.opacity(0.065)
  static let surfaceSelected = Color(red: 0.96, green: 0.66, blue: 0.30).opacity(0.16)
  static let border = Color.white.opacity(0.085)
  static let borderStrong = Color.white.opacity(0.15)
  static let textPrimary = Color.white.opacity(0.95)
  static let textSecondary = Color.white.opacity(0.62)
  static let textTertiary = Color.white.opacity(0.40)
  static let amber = Color(red: 0.96, green: 0.66, blue: 0.30)
  static let teal = Color(red: 0.30, green: 0.80, blue: 0.64)
  static let blue = Color(red: 0.35, green: 0.66, blue: 0.98)
  static let red = Color(red: 0.95, green: 0.38, blue: 0.34)
  static let purple = Color(red: 0.68, green: 0.55, blue: 0.98)

  /// Brand accent used across the shell.
  static let accent = amber

  static var windowBackground: some View {
    ZStack {
      LinearGradient(
        colors: [backgroundTop, backgroundMiddle, backgroundBottom],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      // Soft aurora glows give the dark UI depth without hurting readability.
      RadialGradient(
        colors: [amber.opacity(0.10), Color.clear],
        center: .topLeading,
        startRadius: 0,
        endRadius: 560
      )
      RadialGradient(
        colors: [blue.opacity(0.07), Color.clear],
        center: .bottomTrailing,
        startRadius: 0,
        endRadius: 620
      )
    }
  }

  static var popoverBackground: some View {
    LinearGradient(
      colors: [backgroundTop.opacity(0.98), backgroundBottom],
      startPoint: .top,
      endPoint: .bottom
    )
  }
}


struct DashboardSplit<Leading: View, Trailing: View>: View {
  private let leading: Leading
  private let trailing: Trailing
  private let trailingWidth: CGFloat

  init(
    trailingWidth: CGFloat = ProcessWatchLayout.detailPanelWidth,
    @ViewBuilder leading: () -> Leading,
    @ViewBuilder trailing: () -> Trailing
  ) {
    self.trailingWidth = trailingWidth
    self.leading = leading()
    self.trailing = trailing()
  }

  var body: some View {
    GeometryReader { proxy in
      let shouldStack = proxy.size.width < 980

      if shouldStack {
        ScrollView {
          VStack(spacing: ProcessWatchLayout.panelGap) {
            leading
              .frame(maxWidth: .infinity)
              .frame(minHeight: 360)
            trailing
              .frame(maxWidth: .infinity)
              .frame(minHeight: 360)
          }
          .frame(maxWidth: .infinity, alignment: .top)
        }
      } else {
        HStack(alignment: .top, spacing: ProcessWatchLayout.panelGap) {
          leading
            .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

          trailing
            .frame(width: min(trailingWidth, max(ProcessWatchLayout.compactDetailPanelWidth, proxy.size.width * 0.34)))
            .frame(maxHeight: .infinity)
            .clipped()
        }
        .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
      }
    }
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
      // Hairline top highlight sells the "raised glass" material.
      .overlay(
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .stroke(
            LinearGradient(
              colors: [Color.white.opacity(elevated ? 0.10 : 0.06), Color.clear],
              startPoint: .top,
              endPoint: .center
            ),
            lineWidth: 1
          )
      )
      .shadow(color: .black.opacity(elevated ? 0.30 : 0.16), radius: elevated ? 20 : 12, y: elevated ? 10 : 6)
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
      .background(color.opacity(0.14), in: Capsule())
      .overlay(
        Capsule()
          .stroke(color.opacity(0.20), lineWidth: 1)
      )
  }
}

struct SectionHeading: View {
  let title: String
  let subtitle: String

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.title2.weight(.bold))
        .foregroundStyle(ProcessWatchTheme.textPrimary)
      Text(subtitle)
        .font(.caption)
        .foregroundStyle(ProcessWatchTheme.textSecondary)
    }
  }
}

struct PageHeaderBar<Title: View, Actions: View>: View {
  private let title: Title
  private let actions: Actions

  init(
    @ViewBuilder title: () -> Title,
    @ViewBuilder actions: () -> Actions
  ) {
    self.title = title()
    self.actions = actions()
  }

  var body: some View {
    ViewThatFits(in: .horizontal) {
      HStack(alignment: .center, spacing: 14) {
        title
        Spacer(minLength: 16)
        actions
      }

      VStack(alignment: .leading, spacing: 12) {
        title
          .frame(maxWidth: .infinity, alignment: .leading)
        actions
          .frame(maxWidth: .infinity, alignment: .leading)
      }
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
      let samples = samplePoints(in: proxy.size, minValue: minValue, range: range)

      ZStack {
        if fill, samples.count > 1 {
          smoothAreaPath(samples: samples, in: proxy.size)
            .fill(
              LinearGradient(
                colors: [color.opacity(0.30), color.opacity(0.02)],
                startPoint: .top,
                endPoint: .bottom
              )
            )
        }

        smoothLinePath(samples: samples)
          .stroke(color, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
          .shadow(color: color.opacity(0.35), radius: 4)

        if let last = samples.last {
          Circle()
            .fill(color)
            .frame(width: 5, height: 5)
            .shadow(color: color.opacity(0.8), radius: 3)
            .position(last)
        }
      }
    }
    .accessibilityHidden(true)
  }

  private func samplePoints(in size: CGSize, minValue: Double, range: Double) -> [CGPoint] {
    guard points.count > 1 else { return [] }
    return points.enumerated().map { index, point in
      let x = size.width * CGFloat(index) / CGFloat(max(points.count - 1, 1))
      let normalized = (point.value - minValue) / range
      let y = size.height - size.height * CGFloat(normalized)
      return CGPoint(x: x, y: y)
    }
  }

  /// Catmull-Rom smoothed polyline for a more organic, modern chart feel.
  private func smoothLinePath(samples: [CGPoint]) -> Path {
    var path = Path()
    guard samples.count > 1 else { return path }
    path.move(to: samples[0])
    for index in 0..<(samples.count - 1) {
      let p0 = samples[max(index - 1, 0)]
      let p1 = samples[index]
      let p2 = samples[index + 1]
      let p3 = samples[min(index + 2, samples.count - 1)]
      let control1 = CGPoint(
        x: p1.x + (p2.x - p0.x) / 6,
        y: p1.y + (p2.y - p0.y) / 6
      )
      let control2 = CGPoint(
        x: p2.x - (p3.x - p1.x) / 6,
        y: p2.y - (p3.y - p1.y) / 6
      )
      path.addCurve(to: p2, control1: control1, control2: control2)
    }
    return path
  }

  private func smoothAreaPath(samples: [CGPoint], in size: CGSize) -> Path {
    var path = smoothLinePath(samples: samples)
    guard samples.count > 1 else { return path }
    path.addLine(to: CGPoint(x: size.width, y: size.height))
    path.addLine(to: CGPoint(x: 0, y: size.height))
    path.closeSubpath()
    return path
  }
}

/// Circular health / gauge ring used by the overview hero and metric cards.
struct HealthRing: View {
  /// 0...1
  let progress: Double
  let color: Color
  var lineWidth: CGFloat = 9
  var trackOpacity: Double = 0.12

  var body: some View {
    ZStack {
      Circle()
        .stroke(color.opacity(trackOpacity), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
      Circle()
        .trim(from: 0, to: CGFloat(max(0.0, min(progress, 1.0))))
        .stroke(
          AngularGradient(
            colors: [color.opacity(0.45), color],
            center: .center,
            startAngle: .degrees(0),
            endAngle: .degrees(360 * max(0.02, min(progress, 1.0)))
          ),
          style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
        )
        .rotationEffect(.degrees(-90))
        .shadow(color: color.opacity(0.45), radius: 6)
    }
    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
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

  @State private var isHovering = false

  var body: some View {
    DashboardCard(padding: 16, elevated: isHovering) {
      VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 8) {
          ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
              .fill(accent.opacity(0.14))
              .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                  .stroke(accent.opacity(0.22), lineWidth: 1)
              )
            Image(systemName: systemImage)
              .font(.callout.weight(.semibold))
              .foregroundStyle(accent)
          }
          .frame(width: 28, height: 28)

          Text(title.uppercased())
            .font(.caption.weight(.bold))
            .tracking(1.1)
            .foregroundStyle(ProcessWatchTheme.textSecondary)
          Spacer(minLength: 4)
          StatusPill(text: statusText, color: statusColor)
        }

        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Text(value)
            .font(.system(size: 32, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(ProcessWatchTheme.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.62)
          Text(detail)
            .font(.caption)
            .foregroundStyle(ProcessWatchTheme.textSecondary)
            .lineLimit(2)
          Spacer(minLength: 0)
        }

        Sparkline(points: points, color: accent)
          .frame(height: 52)

        Text(footer)
          .font(.caption)
          .monospacedDigit()
          .foregroundStyle(ProcessWatchTheme.textSecondary)
          .lineLimit(1)
          .minimumScaleFactor(0.72)
      }
    }
    .frame(minHeight: 158)
    .scaleEffect(isHovering ? 1.012 : 1)
    .animation(.spring(response: 0.32, dampingFraction: 0.72), value: isHovering)
    .onHover { isHovering = $0 }
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
    ProcessWatchButtonBody(kind: kind, isEnabled: isEnabled, configuration: configuration)
  }

  private struct ProcessWatchButtonBody: View {
    let kind: ProcessWatchButtonKind
    let isEnabled: Bool
    let configuration: Configuration
    @State private var isHovering = false

    var body: some View {
      configuration.label
        .font(.callout.weight(.medium))
        .foregroundStyle(foreground)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
          RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(background.opacity(configuration.isPressed ? 0.72 : 1))
            .overlay(
              RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.white.opacity(isHovering ? 0.07 : 0))
            )
        )
        .overlay(
          RoundedRectangle(cornerRadius: 9, style: .continuous)
            .stroke(isHovering ? border.opacity(1.6) : border, lineWidth: 1)
        )
        .opacity(isEnabled ? 1 : 0.45)
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .onHover { isHovering = $0 }
    }

    private var background: Color {
      switch kind {
      case .primary: return ProcessWatchTheme.amber.opacity(0.24)
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
      case .primary: return ProcessWatchTheme.amber.opacity(0.30)
      case .secondary, .subtle: return ProcessWatchTheme.border
      case .danger: return ProcessWatchTheme.red.opacity(0.35)
      }
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
