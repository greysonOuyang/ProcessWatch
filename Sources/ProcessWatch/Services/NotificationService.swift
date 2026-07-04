import Foundation
import UserNotifications

final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
  static let shared = NotificationService()

  var onOpenAlerts: (@MainActor () -> Void)?

  private override init() {
    super.init()
    UNUserNotificationCenter.current().delegate = self
  }

  func requestAuthorization() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
  }

  func send(event: AnomalyEvent) {
    let content = UNMutableNotificationContent()
    content.title = event.title
    content.subtitle = event.processName
    content.body = event.detail
    content.sound = .default
    content.userInfo = [
      "processName": event.processName,
      "processPath": event.processPath,
      "anomalyKind": event.kind.rawValue,
    ]

    let request = UNNotificationRequest(
      identifier: event.id.uuidString,
      content: content,
      trigger: nil
    )
    UNUserNotificationCenter.current().add(request)
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .sound])
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    Task { @MainActor in
      onOpenAlerts?()
      completionHandler()
    }
  }
}
