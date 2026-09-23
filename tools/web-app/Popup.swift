import Cocoa
import WebKit

final class PopupWindow: NSObject, NSWindowDelegate {
    let webView: WKWebView
    private let window: NSWindow
    private var titleObs: NSKeyValueObservation?
    private let onClose: (PopupWindow) -> Void

    init(configuration: WKWebViewConfiguration, features: WKWindowFeatures,
         title: String, delegate: AppDelegate, onClose: @escaping (PopupWindow) -> Void) {
        let width = features.width.map { CGFloat(truncating: $0) } ?? 900
        let height = features.height.map { CGFloat(truncating: $0) } ?? 700
        let rect = NSRect(x: 0, y: 0, width: max(width, 320), height: max(height, 240))
        webView = WKWebView(frame: rect, configuration: configuration)
        window = NSWindow(contentRect: rect,
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
        self.onClose = onClose
        super.init()
        webView.autoresizingMask = [.width, .height]
        webView.allowsMagnification = true
        if #available(macOS 13.3, *) { webView.isInspectable = delegate.inspectable }
        webView.uiDelegate = delegate
        webView.navigationDelegate = delegate
        window.contentView = webView
        window.title = title
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.center()
        titleObs = webView.observe(\.title, options: [.new]) { [weak self] view, _ in
            guard let live = view.title, !live.isEmpty else { return }
            self?.window.title = live
        }
    }

    func show() {
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        window.close()
    }

    func windowWillClose(_ note: Notification) {
        titleObs = nil
        DispatchQueue.main.async { [self] in onClose(self) }
    }
}

extension AppDelegate {
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        let url = navigationAction.request.url
        if externalLinksInBrowser, let url, let host = url.host, !isAppHost(host) {
            NSWorkspace.shared.open(url)
            return nil
        }
        if navigationAction.navigationType == .linkActivated, let url {
            webView.load(URLRequest(url: url))
            return nil
        }
        let popup = PopupWindow(configuration: configuration, features: windowFeatures,
                                title: title, delegate: self) { [weak self] closed in
            self?.popups.removeAll { $0 === closed }
        }
        popups.append(popup)
        popup.show()
        return popup.webView
    }

    func webViewDidClose(_ webView: WKWebView) {
        popups.first { $0.webView === webView }?.close()
    }
}
