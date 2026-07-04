import AppKit
import Foundation

@MainActor
enum ApplicationInfo {
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "开发版"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
    }

    static var displayVersion: String {
        "版本 \(version)（\(build)）"
    }

    static var architecture: String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "unknown"
        #endif
    }

    static var applicationSupportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("ProcessWatch", isDirectory: true)
    }

    static func showAboutPanel() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    static func openDataDirectory() {
        try? FileManager.default.createDirectory(
            at: applicationSupportDirectory,
            withIntermediateDirectories: true
        )
        NSWorkspace.shared.open(applicationSupportDirectory)
    }

    static func copyDiagnostics() -> Bool {
        let processInfo = ProcessInfo.processInfo
        let text = """
        ProcessWatch \(displayVersion)
        macOS: \(processInfo.operatingSystemVersionString)
        Architecture: \(architecture)
        Logical CPUs: \(processInfo.processorCount)
        Physical memory: \(ByteCountFormatter.string(fromByteCount: Int64(processInfo.physicalMemory), countStyle: .memory))
        Bundle: \(Bundle.main.bundleIdentifier ?? "unknown")
        """

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }
}
