import Foundation

enum AppSection: String, CaseIterable, Identifiable, Sendable {
  case overview = "概览"
  case processes = "进程"
  case alerts = "异常"
  case settings = "设置"

  var id: String { rawValue }

  var systemImage: String {
    switch self {
    case .overview: return "gauge.with.dots.needle.67percent"
    case .processes: return "list.bullet.rectangle"
    case .alerts: return "exclamationmark.triangle"
    case .settings: return "gearshape"
    }
  }
}
