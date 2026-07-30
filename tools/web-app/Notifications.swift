import Cocoa
import UserNotifications
import WebKit

// WKWebView has no web-notification support of its own, so the injected shim posts
// page notifications here and we raise real macos ones. the same message channel
// also carries in-app actions from our own pages (the error page's Retry button).
extension AppDelegate {
    func userContentController(_ controller: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        // main-frame only, an embedded frame has no business driving navigation
        if message.name == "webapp" {
            guard message.frameInfo.isMainFrame else { return }
            if (message.body as? [String: Any])?["action"] as? String == "retry" {
                if let url = lastFailedURL { webView.load(URLRequest(url: url)) } else { webView.reload() }
            }
            return
        }
        // notifications only from the app's own origins, a third-party iframe
        // could otherwise post native notifications that look like the app's
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

    // the shim tells the page permission is 'granted' no matter what, so a denial
    // here is invisible to it and every notification just disappears. log it, the
    // Console is the only place this can still show up.
    func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error {
                NSLog("web-app: notification permission request failed: %@", error.localizedDescription)
            } else if !granted {
                NSLog("web-app: notifications are denied for this app, page notifications wont show")
            }
        }
    }

    // show notifications even while the app is frontmost, the default suppress them
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
