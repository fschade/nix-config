import AppKit

// UserDefaults keys. the app registers the config values (from Info.plist, baked
// from the repo json) as defaults, whatever the user changes here goes into the
// standard prefs plist and overrides them, the plain mac way.
let kWebAppLinks = "links"
let kWebAppHomeURL = "homeURL"
let kWebAppAllowSelfSigned = "allowSelfSignedCerts"
let kWebAppKeepRunning = "keepRunningWhenClosed"
let kWebAppExternalLinks = "openExternalLinksInBrowser"

// settings window: edit the start page and the quick-links list. the repo json is
// only the initial default, edits live in UserDefaults, per app, per machine.
final class SettingsController: NSWindowController, NSTableViewDataSource, NSWindowDelegate {
    private let defaultLinks: [[String: String]]
    private let defaultHomeURL: String
    private let defaultAllowSelfSigned: Bool
    private let defaultKeepRunning: Bool
    private let defaultExternalLinks: Bool
    private let onChange: () -> Void

    private var links: [[String: String]] = []
    private let homeField = NSTextField()
    private let table = NSTableView()
    // drag payload for reordering rows: just the source index as a string
    private let rowDragType = NSPasteboard.PasteboardType("dev.webapphost.link.row")
    private let selfSignedCheck = NSButton()
    private let keepRunningCheck = NSButton()
    private let externalLinksCheck = NSButton()

    init(defaultLinks: [[String: String]], defaultHomeURL: String,
         defaultAllowSelfSigned: Bool, defaultKeepRunning: Bool, defaultExternalLinks: Bool,
         onChange: @escaping () -> Void) {
        self.defaultLinks = defaultLinks
        self.defaultHomeURL = defaultHomeURL
        self.defaultAllowSelfSigned = defaultAllowSelfSigned
        self.defaultKeepRunning = defaultKeepRunning
        self.defaultExternalLinks = defaultExternalLinks
        self.onChange = onChange
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 440),
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
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 520, height: 440))

        let homeLabel = NSTextField(labelWithString: "Start page:")
        homeLabel.frame = NSRect(x: 20, y: 408, width: 80, height: 20)
        homeField.frame = NSRect(x: 104, y: 405, width: 396, height: 24)
        homeField.placeholderString = "https://..."
        homeField.target = self
        homeField.action = #selector(save)

        let scroll = NSScrollView(frame: NSRect(x: 20, y: 176, width: 480, height: 220))
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
        addRemove.frame = NSRect(x: 20, y: 146, width: 80, height: 24)

        configureCheck(selfSignedCheck, "Trust self-signed certificates", y: 112)
        configureCheck(keepRunningCheck, "Keep running when the window is closed", y: 88)
        configureCheck(externalLinksCheck, "Open external links in the browser", y: 64)

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
        table.reloadData()
    }

    // persist only real deviations from the baked config: a value equal to the
    // default gets removed again, so a later manifest change shines through and is
    // not shadowed by a frozen copy in the prefs plist.
    @objc private func save() {
        persist(homeField.stringValue, ifDiffersFrom: defaultHomeURL, key: kWebAppHomeURL)
        let d = UserDefaults.standard
        if links == defaultLinks { d.removeObject(forKey: kWebAppLinks) } else { d.set(links, forKey: kWebAppLinks) }
        persist(selfSignedCheck.state == .on, ifDiffersFrom: defaultAllowSelfSigned, key: kWebAppAllowSelfSigned)
        persist(keepRunningCheck.state == .on, ifDiffersFrom: defaultKeepRunning, key: kWebAppKeepRunning)
        persist(externalLinksCheck.state == .on, ifDiffersFrom: defaultExternalLinks, key: kWebAppExternalLinks)
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
        table.reloadData()
        save()
    }

    @objc private func done() {
        save()
        window?.close()
    }

    func windowWillClose(_ notification: Notification) { save() }

    // cell-based table, the columns are editable text backed by the links array
    func numberOfRows(in tableView: NSTableView) -> Int { links.count }

    func tableView(_ tableView: NSTableView, objectValueFor column: NSTableColumn?, row: Int) -> Any? {
        links[row][column?.identifier.rawValue ?? ""] ?? ""
    }

    func tableView(_ tableView: NSTableView, setObjectValue value: Any?, for column: NSTableColumn?, row: Int) {
        guard let key = column?.identifier.rawValue else { return }
        let text = (value as? String) ?? ""
        // an emptied section has to drop the key, the baked links leave it out when
        // it is empty. keeping a "" would make links differ from the defaults for
        // good, and manifest changes stop shining through.
        if key == "section", text.isEmpty {
            links[row].removeValue(forKey: key)
        } else {
            links[row][key] = text
        }
        save()
    }

    // MARK: drag-to-reorder
    // order matters downstream: it drives the menu order, the ⌘1...9 shortcuts and the
    // grouping (adjacent rows with the same label get one heading, the first row with
    // that label is the section's Overview target), so let the user drag rows into place.

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
        // the index comes off the pasteboard, so it can be stale (or foreign):
        // range-check it before it indexes into links
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
