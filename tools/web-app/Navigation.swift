import Cocoa
import WebKit

extension AppDelegate {
    @objc func navigateHome() {
        emitPageEvent("navigate", ["action": "home"])
        if let url = currentSectionHome() ?? homeURL { webView.load(URLRequest(url: url)) }
    }

    private func currentSection() -> String? {
        guard let host = webView.url?.host?.lowercased() else { return nil }
        return menuItems.first { $0.url.host?.lowercased() == host && $0.section != nil }?.section
    }

    private func currentSectionHome() -> URL? {
        guard let section = currentSection() else { return nil }
        return menuItems.first { $0.section == section }?.url
    }

    @objc func navigateBack() {
        emitPageEvent("navigate", ["action": "back"])
        webView.goBack()
    }

    @objc func navigateForward() {
        emitPageEvent("navigate", ["action": "forward"])
        webView.goForward()
    }

    @objc func reloadPage() {
        emitPageEvent("navigate", ["action": "reload"])
        webView.reload()
    }

    @objc func navSegment(_ sender: NSSegmentedControl) {
        if sender.selectedSegment == 0 { navigateBack() } else { navigateForward() }
    }

    @objc func navigateItem(_ sender: NSMenuItem) {
        if let url = sender.representedObject as? URL { webView.load(URLRequest(url: url)) }
    }

    @objc func openInBrowser() {
        emitPageEvent("openInBrowser", [:])
        if let url = webView.url ?? homeURL { NSWorkspace.shared.open(url) }
    }

    @objc func logout() {
        let alert = NSAlert()
        alert.messageText = "Log out of \(title)?"
        alert.informativeText = "This clears the saved session for this app."
        alert.addButton(withTitle: "Log Out")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        emitPageEvent("logout", [:]) // last call: the wipe below takes localStorage with it

        let creds = URLCredentialStorage.shared
        for (space, byUser) in creds.allCredentials {
            for credential in byUser.values { creds.remove(credential, for: space) }
        }
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
        emitPageEvent("zoom", ["level": Double(clamped)])
    }

    // MARK: titlebar

    func updateTitle() {
        guard let field = titleField else { return }
        field.toolTip = webView.url?.absoluteString
        var parts = [title]
        let section = Set(menuItems.compactMap { $0.section }).count > 1 ? currentSection() : nil
        if let section { parts.append(section) }
        if let page = currentPageLabel(), page != title, page != section { parts.append(page) }
        field.stringValue = parts.joined(separator: " — ")
        field.sizeToFit()
    }

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
