import Foundation

struct MetricPoint: Identifiable, Hashable, Sendable {
  let id: UUID
  let date: Date
  let value: Double

  init(id: UUID = UUID(), date: Date = .now, value: Double) {
    self.id = id
    self.date = date
    self.value = value
  }
}

extension Array where Element == MetricPoint {
  mutating func appendSample(_ value: Double, at date: Date, limit: Int = 60) {
    append(MetricPoint(date: date, value: value))
    if count > limit {
      removeFirst(count - limit)
    }
  }
}
