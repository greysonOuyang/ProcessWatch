import Darwin
import Foundation
import ProcessWatchC

actor ProcessSampler {
    private struct PreviousSample {
        let cpuTimeNS: UInt64
        let bytesRead: UInt64
        let bytesWritten: UInt64
        let identity: String
        let date: Date
    }

    private struct RawProcess {
        let pid: Int32
        let ppid: Int32
        let name: String
        let path: String
        let commandLine: String
        let workingDirectory: String
        let startTime: Date?
        let cpuTimeNS: UInt64
        let physicalFootprintBytes: UInt64
        let bytesRead: UInt64
        let bytesWritten: UInt64

        var identity: String {
            let start = startTime?.timeIntervalSince1970 ?? 0
            return "\(name)|\(start)"
        }
    }

    private var previous: [Int32: PreviousSample] = [:]
    private let maximumProcessCount = 8192

    func sample(at date: Date) -> [ProcessSnapshot] {
        var pids = [Int32](repeating: 0, count: maximumProcessCount)
        let count = pids.withUnsafeMutableBufferPointer { buffer -> Int32 in
            guard let baseAddress = buffer.baseAddress else { return 0 }
            return pw_list_pids(baseAddress, Int32(buffer.count))
        }

        guard count > 0 else {
            previous.removeAll()
            return []
        }

        let ownPID = getpid()
        var rawProcesses: [RawProcess] = []
        rawProcesses.reserveCapacity(Int(count))

        for pid in pids.prefix(Int(count)) where pid > 0 && pid != ownPID {
            var raw = PWProcessSample()
            guard pw_read_process(pid, &raw) else { continue }

            let startSeconds = pw_process_sample_start_time_sec(&raw)
            let startMicroseconds = pw_process_sample_start_time_usec(&raw)
            let startTime: Date?
            if startSeconds > 0 {
                startTime = Date(
                    timeIntervalSince1970: TimeInterval(startSeconds) + TimeInterval(startMicroseconds) / 1_000_000
                )
            } else {
                startTime = nil
            }

            rawProcesses.append(RawProcess(
                pid: pid,
                ppid: pw_process_sample_ppid(&raw),
                name: decodedCString(pw_process_sample_name(&raw), fallback: "PID \(pid)"),
                path: decodedCString(pw_process_sample_path(&raw)),
                commandLine: decodedCString(pw_process_sample_command_line(&raw)),
                workingDirectory: decodedCString(pw_process_sample_working_directory(&raw)),
                startTime: startTime,
                cpuTimeNS: pw_process_sample_cpu_time_ns(&raw),
                physicalFootprintBytes: pw_process_sample_physical_footprint_bytes(&raw),
                bytesRead: pw_process_sample_bytes_read(&raw),
                bytesWritten: pw_process_sample_bytes_written(&raw)
            ))
        }

        let processByPID = Dictionary(uniqueKeysWithValues: rawProcesses.map { ($0.pid, $0) })
        var snapshots: [ProcessSnapshot] = []
        snapshots.reserveCapacity(rawProcesses.count)
        var nextPrevious: [Int32: PreviousSample] = [:]

        for raw in rawProcesses {
            let old = previous[raw.pid]
            let interval = max(old.map { date.timeIntervalSince($0.date) } ?? 0, 0.001)

            let cpuPercent: Double
            let readRate: Double
            let writeRate: Double

            if let old, old.identity == raw.identity {
                let cpuDelta = nonNegativeDelta(raw.cpuTimeNS, old.cpuTimeNS)
                let readDelta = nonNegativeDelta(raw.bytesRead, old.bytesRead)
                let writeDelta = nonNegativeDelta(raw.bytesWritten, old.bytesWritten)
                cpuPercent = Double(cpuDelta) / 1_000_000_000 / interval * 100
                readRate = Double(readDelta) / interval
                writeRate = Double(writeDelta) / interval
            } else {
                cpuPercent = 0
                readRate = 0
                writeRate = 0
            }

            let parentName = processByPID[raw.ppid]?.name ?? (raw.ppid == 1 ? "launchd" : "未知")
            let affiliation = classifyAffiliation(for: raw, processByPID: processByPID)

            snapshots.append(ProcessSnapshot(
                pid: raw.pid,
                ppid: raw.ppid,
                name: raw.name,
                parentName: parentName,
                path: raw.path,
                commandLine: raw.commandLine.isEmpty ? raw.path : raw.commandLine,
                workingDirectory: raw.workingDirectory,
                startTime: raw.startTime,
                affiliation: affiliation,
                cpuPercent: cpuPercent.isFinite ? cpuPercent : 0,
                memoryBytes: raw.physicalFootprintBytes,
                diskReadBytesPerSecond: readRate.isFinite ? readRate : 0,
                diskWriteBytesPerSecond: writeRate.isFinite ? writeRate : 0,
                sampledAt: date
            ))

            nextPrevious[raw.pid] = PreviousSample(
                cpuTimeNS: raw.cpuTimeNS,
                bytesRead: raw.bytesRead,
                bytesWritten: raw.bytesWritten,
                identity: raw.identity,
                date: date
            )
        }

        previous = nextPrevious
        return snapshots
    }

    private func classifyAffiliation(
        for process: RawProcess,
        processByPID: [Int32: RawProcess]
    ) -> ProcessAffiliation {
        var searchableParts = [process.name, process.path, process.commandLine, process.workingDirectory]
        var ancestorPID = process.ppid
        var visited = Set<Int32>()

        for _ in 0..<8 where ancestorPID > 0 && !visited.contains(ancestorPID) {
            visited.insert(ancestorPID)
            guard let ancestor = processByPID[ancestorPID] else { break }
            searchableParts.append(contentsOf: [
                ancestor.name,
                ancestor.path,
                ancestor.commandLine,
                ancestor.workingDirectory
            ])
            ancestorPID = ancestor.ppid
        }

        let searchable = searchableParts.joined(separator: " ").lowercased()
        let isRepoHarness = searchable.contains("repo-harness") ||
            searchable.contains("repo_harness") ||
            searchable.contains("repoharness")
        let isCodex = searchable.contains("codex") || searchable.contains("com.openai")

        switch (isRepoHarness, isCodex) {
        case (true, true): return .repoHarnessAndCodex
        case (true, false): return .repoHarness
        case (false, true): return .codex
        case (false, false): return .none
        }
    }

    private func nonNegativeDelta(_ current: UInt64, _ old: UInt64) -> UInt64 {
        current >= old ? current - old : 0
    }

    private func decodedCString(_ pointer: UnsafePointer<CChar>?, fallback: String = "") -> String {
        guard let pointer else { return fallback }
        let result = String(cString: pointer)
        return result.isEmpty ? fallback : result
    }
}
