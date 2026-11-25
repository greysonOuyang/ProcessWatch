import Combine
import Foundation

@MainActor
final class IncidentHistoryStore: ObservableObject {
  @Published private(set) var incidents: [SystemIncidentRecord] = []

  private let fileURL: URL
  private let maxIncidents = 100

  init(fileManager: FileManager = .default) {
    let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    let directory = base.appendingPathComponent("ProcessWatch", isDirectory: true)
    try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    fileURL = directory.appendingPathComponent("system-incidents.json")
    load()
  }

  func add(_ incident: SystemIncidentRecord) {
    incidents.insert(incident, at: 0)
    if incidents.count > maxIncidents {
      incidents.removeLast(incidents.count - maxIncidents)
    }
    persist()
  }

  func clear() {
    incidents.removeAll()
    persist()
  }

  private func load() {
    guard let data = try? Data(contentsOf: fileURL) else { return }
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    incidents = (try? decoder.decode([SystemIncidentRecord].self, from: data)) ?? []
  }

  private func persist() {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    guard let data = try? encoder.encode(incidents) else { return }
    try? data.write(to: fileURL, options: .atomic)
  }
}
