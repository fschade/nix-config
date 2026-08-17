import Cocoa
import WebKit

// per-app page tweaks, baked into the Info.plist by the builder: injected css
// (documentStart, spa-aware url scoping) and js (documentEnd, once per load),
// plus custom toolbar buttons that run js in the page. all of it main frame
// only, evaluateJavaScript cant reach subframes anyway.

struct CustomButton {
    let name: String
    let label: String
    let symbol: String
    let symbolOn: String? // set -> the button is a toggle, click state goes to the page
    let js: String? // nil -> event-only button, the page reacts over webapp:button
    let key: String? // menu shortcut: lowercase = cmd, uppercase = cmd+shift
}

func parseCustomButtons(_ raw: [[String: String]]) -> [CustomButton] {
    raw.compactMap { entry in
        guard let name = entry["name"], let label = entry["label"] else { return nil }
        return CustomButton(name: name, label: label, symbol: entry["symbol"] ?? "wand.and.stars",
                            symbolOn: entry["symbolOn"], js: entry["js"], key: entry["key"])
    }
}

// the page-facing bridge is assets/bridge-shim.js, injected in WebAppHost.swift:
// window.webapp.state mirrors the native ui, every native action lands as a
// "webapp:<type>" custom event, setButtonState drives toggles from the page.

func parseInjected(_ raw: [[String: String]]) -> [(code: String, filter: String?)] {
    raw.compactMap { entry in
        guard let code = entry["code"] else { return nil }
        return (code, entry["urlContains"])
    }
}

// a value as a js literal. json is almost js, except U+2028/29 are line
// terminators in js string literals and would break the script.
private func jsLiteral(_ value: Any) -> String {
    let data = try? JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed])
    let json = data.flatMap { String(data: $0, encoding: .utf8) } ?? "null"
    return json.replacingOccurrences(of: "\u{2028}", with: "\\u2028")
        .replacingOccurrences(of: "\u{2029}", with: "\\u2029")
}

// assets/css-inject.js manages the injected styles (spa-aware url scoping, see
// the comments there), this only fills its entries placeholder
func cssInjectionScript(_ entries: [(code: String, filter: String?)]) -> WKUserScript {
    let payload = entries.map { ["css": $0.code, "filter": $0.filter ?? ""] }
    let source = assetString("css-inject.js")
        .replacingOccurrences(of: "__WEBAPP_ENTRIES__", with: jsLiteral(payload))
    return WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: true)
}

// injected js runs once per document load. a url filter is checked at that
// moment only, spa route changes dont re-run it: page-state tweaks that must
// follow routes belong in css or in a button.
func jsInjectionScript(_ entry: (code: String, filter: String?)) -> WKUserScript {
    var source = entry.code
    if let filter = entry.filter {
        source = "if (location.href.indexOf(\(jsLiteral(filter))) !== -1) {\n\(source)\n}"
    }
    return WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
}

extension AppDelegate {
    // fire a "webapp:<type>" event in the page, the bridge shim dispatches it
    func emitPageEvent(_ type: String, _ detail: [String: Any] = [:]) {
        let js = "window.__webappEmit && window.__webappEmit(\(jsLiteral(type)), \(jsLiteral(detail)))"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    // the full ui state as webapp:ready, after every load: injected js that runs
    // before this sees the empty defaults, the event is the reliable signal
    func pushPageState() {
        let buttons = Dictionary(uniqueKeysWithValues: customButtons.map { ($0.name, customStates[$0.name] ?? false) })
        emitPageEvent("ready", ["audioMuted": audioMuted,
                                "micMuted": webView.microphoneCaptureState == .muted,
                                "buttons": buttons])
    }

    // one action for the toolbar item and the menu item of a custom button
    @objc func runCustomAction(_ sender: Any) {
        var name: String?
        if let item = sender as? NSToolbarItem { name = customName(of: item.itemIdentifier) }
        if let item = sender as? NSMenuItem { name = item.representedObject as? String }
        guard let name, let button = customButtons.first(where: { $0.name == name }) else { return }
        // without js the click is pure signal: a toggle flips natively, the page
        // reacts over the event (and may correct via setButtonState)
        guard let js = button.js else {
            var detail: [String: Any] = ["name": name]
            if button.symbolOn != nil {
                let next = !(customStates[name] ?? false)
                customStates[name] = next
                updateCustomButtons()
                detail["state"] = next
            }
            emitPageEvent("button", detail)
            return
        }
        webView.evaluateJavaScript(js) { [weak self] result, error in
            guard let self else { return }
            if let error {
                NSLog("web-app: button %@ failed: %@", name, error.localizedDescription)
                return
            }
            var detail: [String: Any] = ["name": name]
            // toggles: the script's last expression is the new state
            if button.symbolOn != nil {
                let state = (result as? NSNumber)?.boolValue ?? false
                self.customStates[name] = state
                self.updateCustomButtons()
                detail["state"] = state
            }
            self.emitPageEvent("button", detail)
        }
    }

    func customIdentifier(for name: String) -> NSToolbarItem.Identifier {
        NSToolbarItem.Identifier("custom:\(name)")
    }

    func customName(of id: NSToolbarItem.Identifier) -> String? {
        id.rawValue.hasPrefix("custom:") ? String(id.rawValue.dropFirst("custom:".count)) : nil
    }

    // an unknown sf symbol name renders as an empty button, fall back visibly
    func customSymbol(_ name: String, _ desc: String) -> NSImage {
        NSImage(systemSymbolName: name, accessibilityDescription: desc)
            ?? symbol("wand.and.stars", desc)
    }

    func updateCustomButtons() {
        for item in window.toolbar?.items ?? [] {
            guard let name = customName(of: item.itemIdentifier),
                  let button = customButtons.first(where: { $0.name == name }) else { continue }
            let on = customStates[name] ?? false
            item.image = customSymbol(on ? (button.symbolOn ?? button.symbol) : button.symbol, button.label)
        }
    }
}
