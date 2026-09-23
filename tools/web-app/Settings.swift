import AppKit

let kWebAppLinks = "links"
let kWebAppHomeURL = "homeURL"
let kWebAppAllowSelfSigned = "allowSelfSignedCerts"
let kWebAppKeepRunning = "keepRunningWhenClosed"
let kWebAppExternalLinks = "openExternalLinksInBrowser"
let kWebAppInspectable = "inspectable"
let kWebAppToolbar = "toolbarButtons"

enum ToolbarEntry {
    case button(String)
    case group([String])
    case split
}

let defaultToolbarLayout: [ToolbarEntry] = [
    .button("home"), .button("links"), .split,
    .button("nav"), .button("reload"), .button("openInBrowser"), .button("logout"),
]

let toolbarButtonLabels: [String: String] = [
    "home": "Overview",
    "links": "Links menu",
    "nav": "Back / Forward",
    "reload": "Reload",
    "muteAudio": "Mute sound",
    "muteMic": "Mute microphone",
    "openInBrowser": "Open in Browser",
    "logout": "Log Out",
]

func toolbarLayoutNames(_ layout: [ToolbarEntry]) -> [String] {
    layout.flatMap { entry -> [String] in
        switch entry {
        case .button(let name): return [name]
        case .group(let names): return names
        case .split: return []
        }
    }
}

func parseToolbarLayout(_ raw: [Any]) -> [ToolbarEntry] {
    raw.compactMap { item in
        if let s = item as? String { return s == "|" ? .split : .button(s) }
        if let names = item as? [String] { return .group(names) }
        return nil
    }
}

final class SettingsController: NSWindowController, NSTableViewDataSource, NSWindowDelegate {
    private let defaultLinks: [[String: String]]
    private let defaultHomeURL: String
    private let defaultAllowSelfSigned: Bool
    private let defaultKeepRunning: Bool
    private let defaultExternalLinks: Bool
    private let defaultInspectable: Bool
    private let defaultToolbar: [String]
    private let toolbarLabels: [String: String] // builtin labels + custom button labels
    private let onChange: () -> Void

    private var links: [[String: String]] = []
    private let homeField = NSTextField()
    private let table = NSTableView()
    private let rowDragType = NSPasteboard.PasteboardType("dev.webapphost.link.row")
    private let selfSignedCheck = NSButton()
    private let keepRunningCheck = NSButton()
    private let externalLinksCheck = NSButton()
    private let inspectableCheck = NSButton()
    private var toolbarChecks: [String: NSButton] = [:]

    private static func contentHeight(buttons: Int) -> CGFloat {
        614 + CGFloat(max(0, (buttons + 1) / 2 - 4)) * 24
    }

    init(defaultLinks: [[String: String]], defaultHomeURL: String,
         defaultAllowSelfSigned: Bool, defaultKeepRunning: Bool, defaultExternalLinks: Bool,
         defaultInspectable: Bool, defaultToolbar: [String], toolbarLabels: [String: String],
         onChange: @escaping () -> Void) {
        self.defaultLinks = defaultLinks
        self.defaultHomeURL = defaultHomeURL
        self.defaultAllowSelfSigned = defaultAllowSelfSigned
        self.defaultKeepRunning = defaultKeepRunning
        self.defaultExternalLinks = defaultExternalLinks
        self.defaultInspectable = defaultInspectable
        self.defaultToolbar = defaultToolbar
        self.toolbarLabels = toolbarLabels
        self.onChange = onChange
        let height = Self.contentHeight(buttons: defaultToolbar.count)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: height),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Settings"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        buildUI()
        load()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    private func buildUI() {
        let h = Self.contentHeight(buttons: defaultToolbar.count)
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 520, height: h))

        let homeLabel = NSTextField(labelWithString: "Start page:")
        homeLabel.frame = NSRect(x: 20, y: h - 32, width: 80, height: 20)
        homeField.frame = NSRect(x: 104, y: h - 35, width: 396, height: 24)
        homeField.placeholderString = "https://..."
        homeField.target = self
        homeField.action = #selector(save)

        let scroll = NSScrollView(frame: NSRect(x: 20, y: h - 264, width: 480, height: 220))
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        let titleCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("title"))
        titleCol.title = "Title"; titleCol.width = 120; titleCol.isEditable = true
        let sectionCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("section"))
        sectionCol.title = "Section"; sectionCol.width = 110; sectionCol.isEditable = true
        sectionCol.headerToolTip = "Optional group heading; adjacent rows with the same section sit under one heading"
        let urlCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("url"))
        urlCol.title = "URL"; urlCol.width = 236; urlCol.isEditable = true
        table.addTableColumn(titleCol)
        table.addTableColumn(sectionCol)
        table.addTableColumn(urlCol)
        table.dataSource = self
        table.usesAlternatingRowBackgroundColors = true
        table.registerForDraggedTypes([rowDragType])
        scroll.documentView = table

        let addRemove = NSSegmentedControl(labels: ["+", "−"], trackingMode: .momentary,
                                           target: self, action: #selector(addOrRemove(_:)))
        addRemove.frame = NSRect(x: 20, y: h - 294, width: 80, height: 24)

        configureCheck(selfSignedCheck, "Trust self-signed certificates", y: h - 328)
        configureCheck(keepRunningCheck, "Keep running when the window is closed", y: h - 352)
        configureCheck(externalLinksCheck, "Open external links in the browser", y: h - 376)
        configureCheck(inspectableCheck, "Enable the Web Inspector", y: h - 400)

        let toolbarLabel = NSTextField(labelWithString: "Toolbar buttons:")
        toolbarLabel.frame = NSRect(x: 20, y: h - 436, width: 200, height: 20)
        content.addSubview(toolbarLabel)
        for (i, name) in defaultToolbar.enumerated() {
            let check = NSButton()
            check.setButtonType(.switch)
            check.title = toolbarLabels[name] ?? name
            check.target = self
            check.action = #selector(save)
            check.frame = NSRect(x: 20 + CGFloat(i % 2) * 250, y: h - 464 - CGFloat(i / 2) * 24,
                                 width: 230, height: 20)
            toolbarChecks[name] = check
            content.addSubview(check)
        }

        let restore = NSButton(title: "Restore Defaults", target: self, action: #selector(restoreDefaults))
        restore.frame = NSRect(x: 250, y: 16, width: 150, height: 30)
        restore.bezelStyle = .rounded
        let done = NSButton(title: "Done", target: self, action: #selector(done))
        done.frame = NSRect(x: 420, y: 16, width: 80, height: 30)
        done.bezelStyle = .rounded
        done.keyEquivalent = "\r"

        content.addSubview(homeLabel)
        content.addSubview(homeField)
        content.addSubview(scroll)
        content.addSubview(addRemove)
        content.addSubview(selfSignedCheck)
        content.addSubview(keepRunningCheck)
        content.addSubview(externalLinksCheck)
        content.addSubview(inspectableCheck)
        content.addSubview(restore)
        content.addSubview(done)
        window?.contentView = content
        window?.center()
    }

    private func configureCheck(_ check: NSButton, _ title: String, y: CGFloat) {
        check.setButtonType(.switch)
        check.title = title
        check.target = self
        check.action = #selector(save)
        check.frame = NSRect(x: 20, y: y, width: 400, height: 20)
    }

    private func load() {
        let d = UserDefaults.standard
        homeField.stringValue = d.string(forKey: kWebAppHomeURL) ?? defaultHomeURL
        links = d.array(forKey: kWebAppLinks) as? [[String: String]] ?? defaultLinks
        selfSignedCheck.state = d.bool(forKey: kWebAppAllowSelfSigned) ? .on : .off
        keepRunningCheck.state = d.bool(forKey: kWebAppKeepRunning) ? .on : .off
        externalLinksCheck.state = d.bool(forKey: kWebAppExternalLinks) ? .on : .off
        inspectableCheck.state = d.bool(forKey: kWebAppInspectable) ? .on : .off
        let buttons = Set(d.array(forKey: kWebAppToolbar) as? [String] ?? defaultToolbar)
        for (name, check) in toolbarChecks { check.state = buttons.contains(name) ? .on : .off }
        table.reloadData()
    }

    @objc private func save() {
        persist(homeField.stringValue, ifDiffersFrom: defaultHomeURL, key: kWebAppHomeURL)
        let d = UserDefaults.standard
        if links == defaultLinks { d.removeObject(forKey: kWebAppLinks) } else { d.set(links, forKey: kWebAppLinks) }
        persist(selfSignedCheck.state == .on, ifDiffersFrom: defaultAllowSelfSigned, key: kWebAppAllowSelfSigned)
        persist(keepRunningCheck.state == .on, ifDiffersFrom: defaultKeepRunning, key: kWebAppKeepRunning)
        persist(externalLinksCheck.state == .on, ifDiffersFrom: defaultExternalLinks, key: kWebAppExternalLinks)
        persist(inspectableCheck.state == .on, ifDiffersFrom: defaultInspectable, key: kWebAppInspectable)
        let enabled = defaultToolbar.filter { toolbarChecks[$0]?.state == .on }
        if Set(enabled) == Set(defaultToolbar) { d.removeObject(forKey: kWebAppToolbar) } else { d.set(enabled, forKey: kWebAppToolbar) }
        onChange()
    }

    private func persist(_ value: String, ifDiffersFrom def: String, key: String) {
        let d = UserDefaults.standard
        if value == def { d.removeObject(forKey: key) } else { d.set(value, forKey: key) }
    }

    private func persist(_ value: Bool, ifDiffersFrom def: Bool, key: String) {
        let d = UserDefaults.standard
        if value == def { d.removeObject(forKey: key) } else { d.set(value, forKey: key) }
    }

    @objc private func addOrRemove(_ sender: NSSegmentedControl) {
        if sender.selectedSegment == 0 {
            links.append(["title": "New link", "url": "https://"])
        } else if table.selectedRow >= 0 {
            links.remove(at: table.selectedRow)
        }
        table.reloadData()
        save()
    }

    @objc private func restoreDefaults() {
        homeField.stringValue = defaultHomeURL
        links = defaultLinks
        selfSignedCheck.state = defaultAllowSelfSigned ? .on : .off
        keepRunningCheck.state = defaultKeepRunning ? .on : .off
        externalLinksCheck.state = defaultExternalLinks ? .on : .off
        inspectableCheck.state = defaultInspectable ? .on : .off
        for (_, check) in toolbarChecks { check.state = .on } // the default is "everything the layout has"
        table.reloadData()
        save()
    }

    @objc private func done() {
        save()
        window?.close()
    }

    func windowWillClose(_ notification: Notification) { save() }

    func numberOfRows(in tableView: NSTableView) -> Int { links.count }

    func tableView(_ tableView: NSTableView, objectValueFor column: NSTableColumn?, row: Int) -> Any? {
        links[row][column?.identifier.rawValue ?? ""] ?? ""
    }

    func tableView(_ tableView: NSTableView, setObjectValue value: Any?, for column: NSTableColumn?, row: Int) {
        guard let key = column?.identifier.rawValue else { return }
        let text = (value as? String) ?? ""
        if key == "section", text.isEmpty {
            links[row].removeValue(forKey: key)
        } else {
            links[row][key] = text
        }
        save()
    }

    // MARK: drag-to-reorder

    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        let item = NSPasteboardItem()
        item.setString(String(row), forType: rowDragType)
        return item
    }

    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo,
                   proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        dropOperation == .above ? .move : []
    }

    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo,
                   row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        guard let item = info.draggingPasteboard.pasteboardItems?.first,
              let source = item.string(forType: rowDragType).flatMap(Int.init),
              links.indices.contains(source) else { return false }
        var dest = min(max(row, 0), links.count)
        let moved = links.remove(at: source)
        if source < dest { dest -= 1 } // account for the row we just pulled out
        links.insert(moved, at: dest)
        table.reloadData()
        table.selectRowIndexes(IndexSet(integer: dest), byExtendingSelection: false)
        save()
        return true
    }
}
