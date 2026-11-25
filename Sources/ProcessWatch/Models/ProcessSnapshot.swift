import Darwin
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

enum ProcessDisposition: String, Hashable, Sendable {
    case currentUser = "当前用户"
    case otherUser = "其他用户"
    case root = "root"
    case system = "系统"
    case unknown = "身份未知"
}

enum ProcessActionability: String, Hashable, Sendable {
    case actionable = "可操作"
    case protected = "受保护"
    case requiresPrivilege = "需要更高权限"
    case unverifiable = "无法验证"
}

struct ProcessIdentity: Hashable, Sendable {
    let pid: Int32
    let name: String
    let path: String
    let startTime: Date?
    let userID: UInt32
    let effectiveUserID: UInt32
    let isReliable: Bool
}

struct ProcessSafetyAssessment: Hashable, Sendable {
    let disposition: ProcessDisposition
    let actionability: ProcessActionability
    let reason: String

    var canTerminate: Bool {
        actionability == .actionable
    }
}

enum ProcessSafetyPolicy {
    static let protectedNames: Set<String> = [
        "kernel_task", "launchd", "windowserver", "loginwindow", "runningboardd", "powerd",
        "mds", "mds_stores", "fseventsd", "syslogd", "securityd", "opendirectoryd",
        "notifyd", "coreservicesd", "distnoted", "diskarbitrationd", "configd",
    ]

    static let protectedPathPrefixes = [
        "/System/", "/usr/libexec/", "/usr/sbin/", "/sbin/", "/Library/Apple/",
        "/Library/PrivilegedHelperTools/",
    ]

    static func assess(
        _ process: ProcessSnapshot,
        currentUserID: UInt32 = getuid(),
        ownPID: Int32 = getpid()
    ) -> ProcessSafetyAssessment {
        if process.pid <= 1 {
            return ProcessSafetyAssessment(
                disposition: .system,
                actionability: .protected,
                reason: "PID 1 或内核进程受保护"
            )
        }
        if process.pid == ownPID {
            return ProcessSafetyAssessment(
                disposition: .currentUser,
                actionability: .protected,
                reason: "ProcessWatch 自身受保护"
            )
        }
        guard process.identityIsReliable else {
            return ProcessSafetyAssessment(
                disposition: .unknown,
                actionability: .unverifiable,
                reason: "无法可靠读取进程所有者和启动身份"
            )
        }
        guard !process.name.isEmpty, !process.path.isEmpty, process.startTime != nil else {
            return ProcessSafetyAssessment(
                disposition: .unknown,
                actionability: .unverifiable,
                reason: "进程名称、路径或启动时间不完整"
            )
        }
        if protectedNames.contains(process.name.lowercased())
            || protectedPathPrefixes.contains(where: process.path.hasPrefix)
        {
            return ProcessSafetyAssessment(
                disposition: .system,
                actionability: .protected,
                reason: "macOS 系统或受保护目录中的进程"
            )
        }
        if process.userID == 0 || process.effectiveUserID == 0 {
            return ProcessSafetyAssessment(
                disposition: .root,
                actionability: .requiresPrivilege,
                reason: "root 拥有的进程不由 ProcessWatch 终止"
            )
        }
        guard process.userID == currentUserID, process.effectiveUserID == currentUserID else {
            return ProcessSafetyAssessment(
                disposition: .otherUser,
                actionability: .requiresPrivilege,
                reason: "该进程不完全属于当前登录用户"
            )
        }
        return ProcessSafetyAssessment(
            disposition: .currentUser,
            actionability: .actionable,
            reason: "身份完整且属于当前用户"
        )
    }

    static func identitiesMatch(expected: ProcessIdentity, actual: ProcessIdentity) -> Bool {
        guard expected.isReliable, actual.isReliable,
              expected.pid == actual.pid,
              expected.name == actual.name,
              expected.path == actual.path,
              expected.userID == actual.userID,
              expected.effectiveUserID == actual.effectiveUserID,
              let expectedStart = expected.startTime,
              let actualStart = actual.startTime
        else { return false }

        return abs(expectedStart.timeIntervalSince(actualStart)) < 0.01
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
    let userID: UInt32
    let effectiveUserID: UInt32
    let identityIsReliable: Bool
    let affiliation: ProcessAffiliation
    let cpuPercent: Double
    let memoryBytes: UInt64
    let diskReadBytesPerSecond: Double
    let diskWriteBytesPerSecond: Double
    let sampledAt: Date

    var id: Int32 { pid }

    var isLaunchdManaged: Bool {
        ppid == 1
    }

    var identity: ProcessIdentity {
        ProcessIdentity(
            pid: pid,
            name: name,
            path: path,
            startTime: startTime,
            userID: userID,
            effectiveUserID: effectiveUserID,
            isReliable: identityIsReliable
        )
    }

    var safetyAssessment: ProcessSafetyAssessment {
        ProcessSafetyPolicy.assess(self)
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
            String(ppid),
            String(userID),
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
    let launchdManagedCount: Int
    let longestRuntime: TimeInterval
    let repoHarnessCount: Int
    let codexCount: Int

    var instanceCount: Int { processes.count }

    var actionableProcesses: [ProcessSnapshot] {
        processes.filter { $0.safetyAssessment.canTerminate }
    }

    var actionableProcessCount: Int {
        actionableProcesses.count
    }

    var blockedProcessCount: Int {
        instanceCount - actionableProcessCount
    }

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
                launchdManagedCount: sortedMembers.reduce(0) { $0 + ($1.isLaunchdManaged ? 1 : 0) },
                longestRuntime: sortedMembers.map(\.runtime).max() ?? 0,
                repoHarnessCount: sortedMembers.reduce(0) { $0 + ($1.affiliation.belongsToRepoHarness ? 1 : 0) },
                codexCount: sortedMembers.reduce(0) { $0 + ($1.affiliation.belongsToCodex ? 1 : 0) }
            )
        }
    }
}
