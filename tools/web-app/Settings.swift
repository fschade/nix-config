import AppKit

// UserDefaults keys. The app registers the config's values (from Info.plist,
// baked from the repo json) as defaults; whatever the user changes here is
// written to the standard prefs plist and overrides them — the plain mac way.
let kWebAppLinks = "links"
let kWebAppHomeURL = "homeURL"
let kWebAppAllowSelfSigned = "allowSelfSignedCerts"
let kWebAppKeepRunning = "keepRunningWhenClosed"
let kWebAppExternalLinks = "openExternalLinksInBrowser"

// Settings window: edit the start page and the quick-links list. The repo json is
// only the initial default; edits live in UserDefaults, per app, per machine.
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
        homeField.placeholderString = "https://…"
        homeField.target = self
        homeField.action = #selector(save)

        let scroll = NSScrollView(frame: NSRect(x: 20, y: 176, width: 480, height: 220))
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        let titleCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("title"))
        titleCol.title = "Title"; titleCol.width = 120; titleCol.isEditable = true
        let sectionCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("section"))
        sectionCol.title = "Section"; sectionCol.width = 110; sectionCol.isEditable = true
        sectionCol.headerToolTip = "Optional group heading; links with the same text sit under one heading"
        let urlCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("url"))
        urlCol.title = "URL"; urlCol.width = 236; urlCol.isEditable = true
        table.addTableColumn(titleCol)
        table.addTableColumn(sectionCol)
        table.addTableColumn(urlCol)
        table.dataSource = self
        table.usesAlternatingRowBackgroundColors = true
        table.registerForDraggedTypes([rowDragType]) // enable drag-to-reorder
        scroll.documentView = table

        let addRemove = NSSegmentedControl(labels: ["+", "−"], trackingMode: .momentaryAccelerator,
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

    @objc private func save() {
        let d = UserDefaults.standard
        d.set(homeField.stringValue, forKey: kWebAppHomeURL)
        d.set(links, forKey: kWebAppLinks)
        d.set(selfSignedCheck.state == .on, forKey: kWebAppAllowSelfSigned)
        d.set(keepRunningCheck.state == .on, forKey: kWebAppKeepRunning)
        d.set(externalLinksCheck.state == .on, forKey: kWebAppExternalLinks)
        onChange()
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

    // cell-based table: two editable text columns backed by the links array
    func numberOfRows(in tableView: NSTableView) -> Int { links.count }

    func tableView(_ tableView: NSTableView, objectValueFor column: NSTableColumn?, row: Int) -> Any? {
        links[row][column?.identifier.rawValue ?? ""] ?? ""
    }

    func tableView(_ tableView: NSTableView, setObjectValue value: Any?, for column: NSTableColumn?, row: Int) {
        guard let key = column?.identifier.rawValue else { return }
        links[row][key] = (value as? String) ?? ""
        save()
    }

    // MARK: drag-to-reorder
    // order matters downstream: it drives the menu order, the ⌘1…9 shortcuts and
    // the section grouping (a section is a run of adjacent rows; its first row is
    // the section's Overview target), so let the user drag rows into place.

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
              let source = item.string(forType: rowDragType).flatMap(Int.init) else { return false }
        var dest = row
        let moved = links.remove(at: source)
        if source < dest { dest -= 1 } // account for the row we just pulled out
        links.insert(moved, at: dest)
        table.reloadData()
        table.selectRowIndexes(IndexSet(integer: dest), byExtendingSelection: false)
        save()
        return true
    }
}
