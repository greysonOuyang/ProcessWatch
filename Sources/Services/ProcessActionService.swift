import AppKit
import Darwin
import Foundation

@MainActor
enum ProcessActionService {
    static func reveal(_ process: ProcessSnapshot) {
        guard !process.path.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: process.path)])
    }

    @discardableResult
    static func terminate(_ process: ProcessSnapshot) -> Bool {
        kill(process.pid, SIGTERM) == 0
    }
}
