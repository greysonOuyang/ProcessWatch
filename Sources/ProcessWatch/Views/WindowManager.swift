import AppKit
import SwiftUI

@MainActor
final class WindowManager: NSObject, NSWindowDelegate {
  static let shared = WindowManager()

  private var windowController: NSWindowController?

  func show(model: AppModel, section: AppSection? = nil) {
    if let section {
      model.selectedSection = section
    }

    if let window = windowController?.window {
      window.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
      return
    }

    let content = MainView()
      .environmentObject(model)
    let hostingController = NSHostingController(rootView: content)
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 1420, height: 860),
      styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    window.title = "ProcessWatch"
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    window.titlebarSeparatorStyle = .none
    window.isMovableByWindowBackground = true
    window.backgroundColor = NSColor(calibratedRed: 0.03, green: 0.03, blue: 0.034, alpha: 1)
    window.appearance = NSAppearance(named: .darkAqua)
    window.minSize = NSSize(width: 1180, height: 720)
    window.contentViewController = hostingController
    window.collectionBehavior = [.fullScreenPrimary]
    window.center()
    window.setFrameAutosaveName("ProcessWatch.MainWindow.v1.5")
    window.delegate = self

    let controller = NSWindowController(window: window)
    windowController = controller
    controller.showWindow(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  func windowWillClose(_ notification: Notification) {
    windowController = nil
  }
}
