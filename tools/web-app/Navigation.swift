import Cocoa
import WebKit

// Navigation actions shared by the toolbar and the menu, plus the section logic
// that makes "Overview" and the titlebar site-aware, plus page zoom.
extension AppDelegate {
    // "Overview" returns you to where you are: the home of the section you're
    // currently in (its first link), else the global start url.
    @objc func navigateHome() {
        if let url = currentSectionHome() ?? homeURL { webView.load(URLRequest(url: url)) }
    }

    // the section that owns the current page's host, if any (matches the first
    // grouped link on that host). drives both "Overview" and the titlebar label.
    private func currentSection() -> String? {
        guard let host = webView.url?.host else { return nil }
        return menuItems.first { $0.url.host == host && $0.section != nil }?.section
    }

    private func currentSectionHome() -> URL? {
        guard let section = currentSection() else { return nil }
        return menuItems.first { $0.section == section }?.url
    }

    @objc func navigateBack() { webView.goBack() }
    @objc func navigateForward() { webView.goForward() }
    @objc func reloadPage() { webView.reload() }

    @objc func navSegment(_ sender: NSSegmentedControl) {
        if sender.selectedSegment == 0 { webView.goBack() } else { webView.goForward() }
    }

    @objc func navigateItem(_ sender: NSMenuItem) {
        if let url = sender.representedObject as? URL { webView.load(URLRequest(url: url)) }
    }

    // open the current page in the default browser (e.g. to use a password manager)
    @objc func openInBrowser() {
        if let url = webView.url ?? homeURL { NSWorkspace.shared.open(url) }
    }

    // real logout: wipe this app's cookies/storage, then back to the start page
    @objc func logout() {
        let alert = NSAlert()
        alert.messageText = "Log out of \(title)?"
        alert.informativeText = "This clears the saved session for this app."
        alert.addButton(withTitle: "Log Out")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let store = webView.configuration.websiteDataStore
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        store.removeData(ofTypes: types, modifiedSince: Date(timeIntervalSince1970: 0)) { [weak self] in
            self?.navigateHome()
        }
    }

    // MARK: zoom

    @objc func zoomIn() { setZoom(webView.magnification + 0.1) }
    @objc func zoomOut() { setZoom(webView.magnification - 0.1) }
    @objc func zoomReset() { setZoom(1.0) }

    private func setZoom(_ value: CGFloat) {
        let clamped = min(max(value, 0.5), 3.0)
        webView.setMagnification(clamped, centeredAt: CGPoint(x: webView.bounds.midX, y: webView.bounds.midY))
    }

    // MARK: titlebar

    // centered titlebar: "app — section — page", as much as applies. the section
    // comes from the current host, the page from a matching link (else the page's
    // own <title>). tooltip stays the current url.
    func updateTitle() {
        guard let field = titleField else { return }
        field.toolTip = webView.url?.absoluteString
        var parts = [title]
        // the section only disambiguates when the app has more than one; a lone
        // section is a constant label that reads as noise (or misleading, like
        // OpenTalk's links all tagged "OpenCloud"), so drop it in that case.
        let section = Set(menuItems.compactMap { $0.section }).count > 1 ? currentSection() : nil
        if let section { parts.append(section) }
        if let page = currentPageLabel(), page != title, page != section { parts.append(page) }
        field.stringValue = parts.joined(separator: " — ")
        field.sizeToFit()
    }

    // the label for the current page: a link that points right at it (clean and
    // controlled), else the page's own <title> with any part that just repeats the
    // app name stripped — titles often tack it on ("Personal - OpenCloud").
    private func currentPageLabel() -> String? {
        if let url = webView.url, let match = menuItems.first(where: { $0.url == url }) {
            return match.title
        }
        var raw = (webView.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        for sep in [" — ", " – ", " - ", " | ", " · "] { raw = raw.replacingOccurrences(of: sep, with: "\u{1}") }
        let parts = raw.components(separatedBy: "\u{1}")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && $0.caseInsensitiveCompare(title) != .orderedSame }
        let cleaned = parts.joined(separator: " – ")
        return cleaned.isEmpty ? nil : cleaned
    }
}
