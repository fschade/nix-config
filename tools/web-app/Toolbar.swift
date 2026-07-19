import Cocoa

// The window toolbar. left: overview + links menu. centered: title. right:
// back/forward, reload, open-in-browser, logout (flexible spaces split the zones).
extension AppDelegate {
    // (re)create the toolbar; called at launch and when settings change so the
    // links dropdown can appear/disappear with the current link set.
    func installToolbar() {
        let toolbar = NSToolbar(identifier: "WebAppToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.centeredItemIdentifiers = [.title]
        window.toolbar = toolbar
        window.toolbarStyle = .unified
        // hide the titlebar text so the toolbar items left-align (browser style);
        // the centered ".title" item shows the app name in the middle instead.
        window.titleVisibility = .hidden
    }

    // the links dropdown only earns its spot when it adds something the toolbar
    // doesn't already: no links, or a lone link that just points home, → hide it.
    private var showsLinks: Bool {
        guard !menuItems.isEmpty else { return false }
        if menuItems.count == 1, menuItems[0].url == homeURL { return false }
        return true
    }

    private func defaultIdentifiers() -> [NSToolbarItem.Identifier] {
        var ids: [NSToolbarItem.Identifier] = [.home]
        if showsLinks { ids.append(.links) }
        var right: [NSToolbarItem.Identifier] = [.nav, .reload, .openInBrowser, .logout]
        if !downloadItems.isEmpty { right.insert(.downloads, at: 0) } // safari-style, once used
        ids += [.flexibleSpace, .title, .flexibleSpace] + right
        return ids
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        defaultIdentifiers()
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        defaultIdentifiers() + [.flexibleSpace, .space]
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier id: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch id {
        case .nav:
            let seg = NSSegmentedControl(
                images: [symbol("chevron.backward", "Back"), symbol("chevron.forward", "Forward")],
                trackingMode: .momentary, target: self, action: #selector(navSegment(_:)))
            seg.segmentStyle = .separated

            let item = NSToolbarItem(itemIdentifier: id)
            item.view = seg
            item.label = "Navigation"
            return item

        case .reload:
            return button(id, "Reload", "arrow.clockwise", #selector(reloadPage))

        case .home:
            return button(id, "Overview", "house", #selector(navigateHome))

        case .openInBrowser:
            return button(id, "Open in Browser", "safari", #selector(openInBrowser))

        case .logout:
            return button(id, "Log Out", "rectangle.portrait.and.arrow.right", #selector(logout))

        case .downloads:
            return makeDownloadsItem(id)

        case .links:
            let item = NSMenuToolbarItem(itemIdentifier: id)
            item.label = "Links"
            item.image = symbol("list.bullet", "Links")
            item.menu = linksMenu()
            return item

        case .title:
            let field = NSTextField(labelWithString: title)
            field.font = .systemFont(ofSize: 13, weight: .semibold)
            field.textColor = .labelColor
            titleField = field
            updateTitle() // reflect the section if a page is already loaded

            let item = NSToolbarItem(itemIdentifier: id)
            item.view = field
            item.visibilityPriority = .high
            return item

        default:
            return nil
        }
    }
}
