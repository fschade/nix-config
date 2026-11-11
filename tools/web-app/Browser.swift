import Cocoa
import WebKit

extension AppDelegate {
    func isAppHost(_ host: String?) -> Bool {
        guard let host = host?.lowercased() else { return false }
        var hosts = Set(menuItems.compactMap { $0.url.host?.lowercased() })
        if let home = homeURL?.host?.lowercased() { hosts.insert(home) }
        return hosts.contains(host) || hosts.contains { host.hasSuffix("." + $0) }
    }

    func webView(_ webView: WKWebView,
                 requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo,
                 type: WKMediaCaptureType,
                 decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(isAppHost(origin.host) ? .grant : .deny)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let handoffSchemes: Set<String> = ["mailto", "tel", "facetime", "facetime-audio", "sms", "maps"]
        if let url = navigationAction.request.url, let scheme = url.scheme?.lowercased(),
           handoffSchemes.contains(scheme) {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        if externalLinksInBrowser, navigationAction.navigationType == .linkActivated,
           let url = navigationAction.request.url, url.host != nil, !isAppHost(url.host) {
            // web links only: smb, vnc or an app scheme would launch its native handler with page-chosen arguments
            if let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
                NSWorkspace.shared.open(url)
            }
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        decisionHandler(navigationResponse.canShowMIMEType ? .allow : .download)
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = self
        beginDownload(download)
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        download.delegate = self
        beginDownload(download)
    }

    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge,
                 completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let space = challenge.protectionSpace
        switch space.authenticationMethod {
        case NSURLAuthenticationMethodHTTPBasic, NSURLAuthenticationMethodHTTPDigest:
            if challenge.previousFailureCount == 0,
               let stored = URLCredentialStorage.shared.defaultCredential(for: space) {
                completionHandler(.useCredential, stored)
            } else if let credential = promptForCredential(host: space.host) {
                URLCredentialStorage.shared.set(credential, for: space)
                completionHandler(.useCredential, credential)
            } else {
                completionHandler(.cancelAuthenticationChallenge, nil)
            }
        case NSURLAuthenticationMethodServerTrust:
            if allowSelfSigned, isAppHost(space.host), let trust = space.serverTrust {
                completionHandler(.useCredential, URLCredential(trust: trust))
            } else {
                completionHandler(.performDefaultHandling, nil)
            }
        default:
            completionHandler(.performDefaultHandling, nil)
        }
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
        completionHandler()
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        completionHandler(alert.runModal() == .alertFirstButtonReturn)
    }

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String,
                 defaultText: String?, initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (String?) -> Void) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = prompt
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.stringValue = defaultText ?? ""
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        completionHandler(alert.runModal() == .alertFirstButtonReturn ? field.stringValue : nil)
    }

    private func promptForCredential(host: String) -> URLCredential? {
        let alert = NSAlert()
        alert.messageText = "Sign in"
        alert.informativeText = "\(host) requires a username and password."
        alert.addButton(withTitle: "Sign In")
        alert.addButton(withTitle: "Cancel")

        let user = NSTextField(frame: NSRect(x: 0, y: 30, width: 260, height: 24))
        user.placeholderString = "Username"
        let password = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        password.placeholderString = "Password"
        let fields = NSView(frame: NSRect(x: 0, y: 0, width: 260, height: 54))
        fields.addSubview(user)
        fields.addSubview(password)
        alert.accessoryView = fields
        alert.window.initialFirstResponder = user

        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        return URLCredential(user: user.stringValue, password: password.stringValue, persistence: .permanent)
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        guard webView === self.webView else { return }
        updateTitle()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard webView === self.webView else { return }
        contentTerminations = 0 // the page stands again, the crash backoff starts over
        updateTitle()
        updateProgress(1)
        applyAudioMute() // the fresh page's shim starts unmuted, the native state wins
        if !customStates.isEmpty {
            customStates = [:]
            updateCustomButtons()
        }
        pushPageState() // webapp:ready with the full ui state
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        guard webView === self.webView else { return }
        showErrorPage(error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        guard webView === self.webView else { return }
        showErrorPage(error)
    }

    // MARK: load progress

    func setupProgressBar(in container: NSView) {
        progressBar.wantsLayer = true
        progressBar.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        progressBar.isHidden = true
        progressBar.frame = NSRect(x: 0, y: container.bounds.height - 3, width: 0, height: 3)
        progressBar.autoresizingMask = [.width, .minYMargin]
        container.addSubview(progressBar)
    }

    func updateProgress(_ progress: Double) {
        guard let container = progressBar.superview else { return }
        if progress <= 0 || progress >= 1 {
            progressBar.isHidden = true
            progressBar.frame.size.width = 0
            return
        }
        progressBar.isHidden = false
        progressBar.frame = NSRect(x: 0, y: container.bounds.height - 3,
                                   width: container.bounds.width * CGFloat(progress), height: 3)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        guard webView === self.webView else {
            popups.first { $0.webView === webView }?.close()
            return
        }
        contentTerminations += 1
        guard contentTerminations <= 3 else {
            showErrorPage(NSError(domain: "WebAppHost", code: 1, userInfo: [
                NSLocalizedDescriptionKey:
                    "The page kept crashing. That usually means this Mac is out of memory.",
            ]))
            return
        }
        let target = webView.url ?? homeURL
        let delay = Double(contentTerminations - 1) * 3
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, let target else { return }
            self.webView.load(URLRequest(url: target))
        }
    }

    // MARK: error page

    private func showErrorPage(_ error: Error) {
        let ns = error as NSError
        if ns.code == NSURLErrorCancelled { return }
        if ns.domain == "WebKitErrorDomain", [101, 102, 204].contains(ns.code) { return }
        lastFailedURL = (ns.userInfo[NSURLErrorFailingURLErrorKey] as? URL) ?? webView.url ?? homeURL
        updateProgress(1) // stop the bar
        let host = lastFailedURL?.host ?? title
        webView.loadHTMLString(errorHTML(host: host, message: ns.localizedDescription), baseURL: nil)
    }

    private func errorHTML(host: String, message: String) -> String {
        func escape(_ s: String) -> String {
            s.replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
        }
        return assetString("error-page.html")
            .replacingOccurrences(of: "__HOST__", with: escape(host))
            .replacingOccurrences(of: "__MESSAGE__", with: escape(message))
    }
}
