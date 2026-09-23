import Cocoa
import UserNotifications
import WebKit

extension AppDelegate {
    func userContentController(_ controller: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        if message.name == "webapp" {
            guard message.frameInfo.isMainFrame, let body = message.body as? [String: Any] else { return }
            switch body["action"] as? String {
            case "retry": // the error page's Retry button
                if let url = lastFailedURL { webView.load(URLRequest(url: url)) } else { webView.reload() }
            case "buttonState": // window.webapp.setButtonState: page drives a toggle button
                if let name = body["name"] as? String, let value = body["value"] as? Bool,
                   customButtons.contains(where: { $0.name == name && $0.symbolOn != nil }) {
                    customStates[name] = value
                    updateCustomButtons()
                }
            default:
                break
            }
            return
        }
        guard hasBundle, isAppHost(message.frameInfo.securityOrigin.host),
              let body = message.body as? [String: Any] else { return }
        if body["requestPermission"] != nil {
            requestNotificationAuthorization()
            return
        }
        let text = body["body"] as? String ?? ""
        let heading = (body["title"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? title

        let content = UNMutableNotificationContent()
        content.title = heading
        content.body = text
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error { NSLog("web-app: could not post the notification: %@", error.localizedDescription) }
        }
    }

    func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error {
                NSLog("web-app: notification permission request failed: %@", error.localizedDescription)
            } else if !granted {
                NSLog("web-app: notifications are denied for this app, page notifications wont show")
            }
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        completionHandler()
    }
}
