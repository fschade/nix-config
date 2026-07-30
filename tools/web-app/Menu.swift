import Cocoa

// the menu bar (app / edit / view / window / go) and the about panel. the link
// items are shared with the toolbar's "Links" dropdown via appendLinks.
extension AppDelegate {
    func buildMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()

        let about = appMenu.addItem(withTitle: "About \(title)", action: #selector(showAbout), keyEquivalent: "")
        about.target = self

        appMenu.addItem(.separator())

        let settingsItem = appMenu.addItem(withTitle: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self

        appMenu.addItem(.separator())

        // standard macos services submenu, nil action -> appkit fills + targets it
        let servicesMenu = NSMenu()
        appMenu.addItem(withTitle: "Services", action: nil, keyEquivalent: "").submenu = servicesMenu
        NSApp.servicesMenu = servicesMenu

        appMenu.addItem(.separator())

        // hide/show route to NSApp over the responder chain, so no explicit target
        appMenu.addItem(withTitle: "Hide \(title)", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = appMenu.addItem(withTitle: "Hide Others",
                                         action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")

        appMenu.addItem(.separator())

        appMenu.addItem(withTitle: "Quit \(title)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu

        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: "Edit")

        // undo:/redo: live on NSUndoManager over the responder chain, there is no swift
        // symbol to point #selector at
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")

        editMenu.addItem(.separator())

        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        editMenu.addItem(.separator())

        let find = editMenu.addItem(withTitle: "Find...", action: #selector(showFindBar), keyEquivalent: "f")
        let findNextItem = editMenu.addItem(withTitle: "Find Next", action: #selector(findNext), keyEquivalent: "g")
        let findPrevItem = editMenu.addItem(withTitle: "Find Previous", action: #selector(findPrevious), keyEquivalent: "G")
        for item in [find, findNextItem, findPrevItem] { item.target = self }
        editItem.submenu = editMenu

        let viewItem = NSMenuItem()
        mainMenu.addItem(viewItem)
        let viewMenu = NSMenu(title: "View")

        let zoomIn = viewMenu.addItem(withTitle: "Zoom In", action: #selector(zoomIn), keyEquivalent: "=")
        let zoomOut = viewMenu.addItem(withTitle: "Zoom Out", action: #selector(zoomOut), keyEquivalent: "-")
        let zoomReset = viewMenu.addItem(withTitle: "Actual Size", action: #selector(zoomReset), keyEquivalent: "0")
        for item in [zoomIn, zoomOut, zoomReset] { item.target = self }
        viewItem.submenu = viewMenu

        // explicit way back to a keepRunning app's hidden window. activating the
        // app already re-shows it (applicationDidBecomeActive), this is the menu
        // entry and the ⌘⇧0 shortcut for it.
        let windowItem = NSMenuItem()
        mainMenu.addItem(windowItem)
        let windowMenu = NSMenu(title: "Window")

        let show = windowMenu.addItem(withTitle: "Show \(title)", action: #selector(showMainWindow), keyEquivalent: "0")
        show.keyEquivalentModifierMask = [.command, .shift]
        show.target = self
        // routes over the responder chain, so windowShouldClose still decides
        // whether ⌘W hides (keepRunning) or closes
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowItem.submenu = windowMenu
        NSApp.windowsMenu = windowMenu

        // the go menu mirrors the toolbar, so everything has a keyboard shortcut
        let goItem = NSMenuItem()
        mainMenu.addItem(goItem)
        let goMenu = NSMenu(title: "Go")

        let back = goMenu.addItem(withTitle: "Back", action: #selector(navigateBack), keyEquivalent: "[")
        let forward = goMenu.addItem(withTitle: "Forward", action: #selector(navigateForward), keyEquivalent: "]")
        let reload = goMenu.addItem(withTitle: "Reload", action: #selector(reloadPage), keyEquivalent: "r")

        goMenu.addItem(.separator())

        let home = goMenu.addItem(withTitle: "Overview", action: #selector(navigateHome), keyEquivalent: "H")
        let browser = goMenu.addItem(withTitle: "Open in Browser", action: #selector(openInBrowser), keyEquivalent: "B")
        let out = goMenu.addItem(withTitle: "Log Out", action: #selector(logout), keyEquivalent: "")
        let navItems = [back, forward, reload, home, browser, out]

        if !menuItems.isEmpty {
            goMenu.addItem(.separator())
            appendLinks(to: goMenu, shortcuts: true) // sets its own targets + ⌘1...9
        }
        for item in navItems { item.target = self }
        goItem.submenu = goMenu

        NSApp.mainMenu = mainMenu
    }

    func linksMenu() -> NSMenu {
        let menu = NSMenu()
        appendLinks(to: menu, shortcuts: false)
        return menu
    }

    // link items grouped by section: heading + separator whenever the section label
    // changes. shared by the toolbar dropdown and the go menu; shortcuts assigns
    // ⌘1...9 to the first nine links (go menu only).
    private func appendLinks(to menu: NSMenu, shortcuts: Bool) {
        var lastSection: String? = nil
        for (i, entry) in menuItems.enumerated() {
            if entry.section != lastSection {
                // a group change gets a separator once there is something above it
                // to separate from, a named group also gets a heading
                if menu.items.contains(where: { $0.representedObject is URL }) { menu.addItem(.separator()) }
                if let s = entry.section { menu.addItem(sectionHeader(s)) }
            }
            lastSection = entry.section
            let key = shortcuts && i < 9 ? String(i + 1) : ""
            let item = menu.addItem(withTitle: entry.title, action: #selector(navigateItem(_:)), keyEquivalent: key)
            item.representedObject = entry.url
            item.target = self
        }
    }

    private func sectionHeader(_ title: String) -> NSMenuItem {
        if #available(macOS 14.0, *) { return NSMenuItem.sectionHeader(title: title) }
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    // MARK: about

    // the standard macos about panel, it picks the app icon up from the bundle
    @objc func showAbout() {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info["CFBundleVersion"] as? String ?? "1"

        // credits = the manifest's description + a clickable homepage link. the
        // author shows on its own line via NSHumanReadableCopyright.
        let small: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.secondaryLabelColor,
        ]
        let credits = NSMutableAttributedString()
        if let desc = info["WebAppDescription"] as? String, !desc.isEmpty {
            credits.append(NSAttributedString(string: desc, attributes: small))
        }
        if let home = info["WebAppHomepage"] as? String, !home.isEmpty, let url = URL(string: home) {
            if credits.length > 0 { credits.append(NSAttributedString(string: "\n\n", attributes: small)) }
            credits.append(NSAttributedString(string: home, attributes: [.font: NSFont.systemFont(ofSize: 11), .link: url]))
        }
        if credits.length == 0 {
            credits.append(NSAttributedString(string: "Native web-app wrapper.", attributes: small))
        }

        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: title,
            .applicationVersion: version,
            .version: "build \(build)",
            .credits: credits,
        ])
        NSApp.activate(ignoringOtherApps: true)
    }
}
