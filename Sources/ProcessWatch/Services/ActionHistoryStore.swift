import Combine
import Foundation

@MainActor
final class ActionHistoryStore: ObservableObject {
  @Published private(set) var records: [UserActionRecord] = []

  private let fileURL: URL
  private let maxRecords = 200

  init(fileManager: FileManager = .default) {
    let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    let directory = base.appendingPathComponent("ProcessWatch", isDirectory: true)
    try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    fileURL = directory.appendingPathComponent("action-history.json")
    load()
  }

  func add(_ record: UserActionRecord) {
    records.insert(record, at: 0)
    if records.count > maxRecords {
      records.removeLast(records.count - maxRecords)
    }
    persist()
  }

  func clear() {
    records.removeAll()
    persist()
  }

  private func load() {
    guard let data = try? Data(contentsOf: fileURL) else { return }
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    records = (try? decoder.decode([UserActionRecord].self, from: data)) ?? []
  }

  private func persist() {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    guard let data = try? encoder.encode(records) else { return }
    try? data.write(to: fileURL, options: .atomic)
  }
}
