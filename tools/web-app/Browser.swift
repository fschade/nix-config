import Cocoa
import WebKit

// Everything the web view does: navigation policy, off-app links, downloads,
// http auth / self-signed certs, the load progress bar and the offline error page.
extension AppDelegate {
    // grant camera/mic to the page (macOS TCC still gates it at the OS level).
    func webView(_ webView: WKWebView,
                 requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo,
                 type: WKMediaCaptureType,
                 decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(.grant)
    }

    // target=_blank / window.open would otherwise be dropped — load it in place.
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url { webView.load(URLRequest(url: url)) }
        return nil
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // app-scheme links (mailto:/tel:/facetime:/…) the web view can't load itself
        // — hand them to whichever app owns the scheme instead of dead-ending.
        let handoffSchemes: Set<String> = ["mailto", "tel", "facetime", "facetime-audio", "sms", "maps"]
        if let url = navigationAction.request.url, let scheme = url.scheme?.lowercased(),
           handoffSchemes.contains(scheme) {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        // clicked link to another domain -> hand off to the default browser (opt-in).
        // gated on .linkActivated so oauth/sso redirects stay inside the app.
        if externalLinksInBrowser, navigationAction.navigationType == .linkActivated,
           let url = navigationAction.request.url, let host = url.host, host != homeURL?.host {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    // things the web view can't display (attachments) become downloads
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

    // http basic/digest auth like a browser: prompt once, keep it in the keychain
    // and reuse it. server-trust (self-signed) only when the app opted in.
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
            if allowSelfSigned, let trust = space.serverTrust {
                completionHandler(.useCredential, URLCredential(trust: trust))
            } else {
                completionHandler(.performDefaultHandling, nil)
            }
        default:
            completionHandler(.performDefaultHandling, nil)
        }
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
        updateTitle()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        updateTitle()
        updateProgress(1)
    }

    // load errors (network down, dns, rejected cert) otherwise leave a blank page —
    // show an inline message with a Retry button instead. the response phase
    // (didFail:) and the provisional phase (didFailProvisionalNavigation:) both land
    // here; provisional is the common one (the server never answered).
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        showErrorPage(error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        showErrorPage(error)
    }

    // MARK: load progress

    // a thin accent-coloured bar pinned to the top edge of the content, width
    // scaled to the load progress; hidden when idle (0) or done (1).
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

    // MARK: error page

    private func showErrorPage(_ error: Error) {
        let ns = error as NSError
        // ignore "failures" that aren't real, or we'd paint the error page over a
        // working page: a load we cancelled/superseded (-999), and WebKit policy
        // interruptions — a navigation that turns into a download reports "frame
        // load interrupted" (WebKitErrorDomain 101/102/204), which is success.
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
        return """
        <!doctype html><html><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
          :root { color-scheme: light dark; }
          body { margin: 0; height: 100vh; display: flex; align-items: center; justify-content: center;
                 font: -apple-system-body, system-ui, sans-serif;
                 background: Canvas; color: CanvasText; }
          .box { text-align: center; max-width: 32rem; padding: 2rem; }
          h1 { font-size: 1.3rem; margin: 0 0 .5rem; }
          p { margin: .25rem 0; opacity: .6; }
          .msg { margin-top: .75rem; font-size: .9rem; }
          button { margin-top: 1.5rem; font: inherit; font-size: .95rem; padding: .5rem 1.4rem;
                   border: 0; border-radius: 8px; background: #0a84ff; color: #fff; cursor: pointer; }
        </style></head><body>
          <div class="box">
            <h1>Can’t reach \(escape(host))</h1>
            <p class="msg">\(escape(message))</p>
            <button onclick="window.webkit.messageHandlers.webapp.postMessage({action:'retry'})">Retry</button>
          </div>
        </body></html>
        """
    }
}
