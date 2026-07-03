import Foundation

enum ProcessAffiliation: String, Hashable, Sendable {
    case none = ""
    case repoHarness = "repo-harness"
    case codex = "Codex"
    case repoHarnessAndCodex = "repo-harness / Codex"

    var belongsToRepoHarness: Bool {
        self == .repoHarness || self == .repoHarnessAndCodex
    }

    var belongsToCodex: Bool {
        self == .codex || self == .repoHarnessAndCodex
    }
}

struct ProcessSnapshot: Identifiable, Hashable, Sendable {
    let pid: Int32
    let ppid: Int32
    let name: String
    let parentName: String
    let path: String
    let commandLine: String
    let workingDirectory: String
    let startTime: Date?
    let affiliation: ProcessAffiliation
    let cpuPercent: Double
    let memoryBytes: UInt64
    let diskReadBytesPerSecond: Double
    let diskWriteBytesPerSecond: Double
    let sampledAt: Date

    var id: Int32 { pid }

    var isOrphan: Bool {
        ppid == 1
    }

    var runtime: TimeInterval {
        guard let startTime else { return 0 }
        return max(0, sampledAt.timeIntervalSince(startTime))
    }

    var executableGroupKey: String {
        if !path.isEmpty {
            return "path:\(path)"
        }
        return "name:\(name.lowercased())"
    }

    func matches(searchText: String) -> Bool {
        guard !searchText.isEmpty else { return true }
        let fields = [
            name,
            parentName,
            path,
            commandLine,
            workingDirectory,
            affiliation.rawValue,
            String(pid),
            String(ppid)
        ]
        return fields.contains { $0.localizedCaseInsensitiveContains(searchText) }
    }
}

struct ProcessGroupSnapshot: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let path: String
    let processes: [ProcessSnapshot]
    let cpuPercent: Double
    let memoryBytes: UInt64
    let diskReadBytesPerSecond: Double
    let diskWriteBytesPerSecond: Double
    let orphanCount: Int
    let longestRuntime: TimeInterval
    let repoHarnessCount: Int
    let codexCount: Int

    var instanceCount: Int { processes.count }

    var representative: ProcessSnapshot? {
        processes.max {
            if $0.cpuPercent == $1.cpuPercent {
                return $0.memoryBytes < $1.memoryBytes
            }
            return $0.cpuPercent < $1.cpuPercent
        }
    }

    var affiliationSummary: String? {
        switch (repoHarnessCount > 0, codexCount > 0) {
        case (true, true): return "repo-harness / Codex"
        case (true, false): return "repo-harness"
        case (false, true): return "Codex"
        case (false, false): return nil
        }
    }

    static func grouped(_ processes: [ProcessSnapshot]) -> [ProcessGroupSnapshot] {
        Dictionary(grouping: processes, by: \.executableGroupKey).map { key, members in
            let sortedMembers = members.sorted {
                if $0.cpuPercent == $1.cpuPercent {
                    return $0.memoryBytes > $1.memoryBytes
                }
                return $0.cpuPercent > $1.cpuPercent
            }
            let first = sortedMembers[0]
            return ProcessGroupSnapshot(
                id: key,
                name: first.name,
                path: first.path,
                processes: sortedMembers,
                cpuPercent: sortedMembers.reduce(0) { $0 + $1.cpuPercent },
                memoryBytes: sortedMembers.reduce(0) { $0 &+ $1.memoryBytes },
                diskReadBytesPerSecond: sortedMembers.reduce(0) { $0 + $1.diskReadBytesPerSecond },
                diskWriteBytesPerSecond: sortedMembers.reduce(0) { $0 + $1.diskWriteBytesPerSecond },
                orphanCount: sortedMembers.reduce(0) { $0 + ($1.isOrphan ? 1 : 0) },
                longestRuntime: sortedMembers.map(\.runtime).max() ?? 0,
                repoHarnessCount: sortedMembers.reduce(0) { $0 + ($1.affiliation.belongsToRepoHarness ? 1 : 0) },
                codexCount: sortedMembers.reduce(0) { $0 + ($1.affiliation.belongsToCodex ? 1 : 0) }
            )
        }
    }
}
