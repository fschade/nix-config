import Cocoa
import UserNotifications
import WebKit

// WKWebView has no web-notification support of its own, so the injected shim posts
// page notifications here and we raise real macOS ones. The same message channel
// also carries in-app actions from our own pages (the error page's Retry button).
extension AppDelegate {
    func userContentController(_ controller: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        // in-app actions from our own pages (the error page's Retry button)
        if message.name == "webapp" {
            if (message.body as? [String: Any])?["action"] as? String == "retry" {
                if let url = lastFailedURL { webView.load(URLRequest(url: url)) } else { webView.reload() }
            }
            return
        }
        guard hasBundle, let body = message.body as? [String: Any] else { return }
        if body["requestPermission"] != nil {
            UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
            return
        }
        let text = body["body"] as? String ?? ""
        let heading = (body["title"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? title

        let content = UNMutableNotificationContent()
        content.title = heading
        content.body = text
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // show notifications even while the app is frontmost (default is to suppress)
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }

    // clicking a notification brings the app to the front
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        completionHandler()
    }
}
