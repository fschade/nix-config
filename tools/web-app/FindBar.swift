import Cocoa

// ⌘F find-on-page: a translucent strip across the top of the content that drives
// webkit's own window.find (which highlights, selects and scrolls to the match).
extension AppDelegate {
    func setupFindBar(in container: NSView) {
        let height: CGFloat = 38
        findBar.material = .headerView
        findBar.blendingMode = .withinWindow
        findBar.state = .active
        findBar.isHidden = true
        findBar.frame = NSRect(x: 0, y: container.bounds.height - height, width: container.bounds.width, height: height)
        findBar.autoresizingMask = [.width, .minYMargin]

        findField.frame = NSRect(x: 12, y: 7, width: 260, height: 24)
        findField.placeholderString = "Find on page"
        findField.target = self
        findField.action = #selector(findNext)
        findField.delegate = self

        let done = NSButton(title: "Done", target: self, action: #selector(hideFindBar))
        done.frame = NSRect(x: findBar.bounds.width - 78, y: 5, width: 66, height: 28)
        done.bezelStyle = .rounded
        done.autoresizingMask = [.minXMargin]

        findBar.addSubview(findField)
        findBar.addSubview(done)
        container.addSubview(findBar)
    }

    @objc func showFindBar() {
        findBar.isHidden = false
        window.makeFirstResponder(findField)
    }

    @objc func hideFindBar() {
        findBar.isHidden = true
        window.makeFirstResponder(webView)
    }

    @objc func findNext() { runFind(backwards: false) }
    @objc func findPrevious() { runFind(backwards: true) }

    // fromStart collapses the selection first so a fresh query searches from the top.
    private func runFind(backwards: Bool, fromStart: Bool = false) {
        let query = findField.stringValue
        guard !query.isEmpty,
              let data = try? JSONEncoder().encode(query),
              let literal = String(data: data, encoding: .utf8) else { return }
        let reset = fromStart ? "window.getSelection().removeAllRanges();" : ""
        webView.evaluateJavaScript("\(reset)window.find(\(literal), false, \(backwards), true)", completionHandler: nil)
    }

    // find as you type (from the top each keystroke)
    func controlTextDidChange(_ obj: Notification) {
        if (obj.object as? NSSearchField) === findField { runFind(backwards: false, fromStart: true) }
    }

    // Esc in the find field closes the bar
    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        if selector == #selector(NSResponder.cancelOperation(_:)) {
            hideFindBar()
            return true
        }
        return false
    }
}
