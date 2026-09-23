import Cocoa

extension AppDelegate {
    func installToolbar() {
        let toolbar = NSToolbar(identifier: "WebAppToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.centeredItemIdentifiers = [.title]
        window.toolbar = toolbar
        window.toolbarStyle = .unified
        window.titleVisibility = .hidden
    }

    var showsLinks: Bool {
        guard !menuItems.isEmpty else { return false }
        if menuItems.count == 1, menuItems[0].url == homeURL { return false }
        return true
    }

    private func defaultIdentifiers() -> [NSToolbarItem.Identifier] {
        var idFor: [String: NSToolbarItem.Identifier] = [
            "home": .home, "links": .links, "nav": .nav, "reload": .reload,
            "muteAudio": .muteAudio, "muteMic": .muteMic,
            "openInBrowser": .openInBrowser, "logout": .logout,
        ]
        for b in customButtons { idFor[b.name] = customIdentifier(for: b.name) }
        func mapped(_ names: [String]) -> [NSToolbarItem.Identifier] {
            names.compactMap { name in
                guard toolbarButtons.contains(name), let id = idFor[name] else { return nil }
                return id == .links && !showsLinks ? nil : id
            }
        }
        var ids: [NSToolbarItem.Identifier] = []
        func add(_ members: [NSToolbarItem.Identifier]) {
            guard !members.isEmpty else { return }
            if let last = ids.last, last != .flexibleSpace { ids.append(.space) }
            ids += members
        }
        var titled = false
        func emitTitle() {
            ids += [.flexibleSpace, .title, .flexibleSpace]
            if !downloadItems.isEmpty { add([.downloads]) } // safari-style, once used
            titled = true
        }
        for entry in bakedToolbarLayout {
            switch entry {
            case .split where !titled:
                emitTitle()
            case .split:
                break // the builder warned already, keep the first
            case .button(let name):
                add(mapped([name]))
            case .group(let names):
                add(mapped(names))
            }
        }
        if !titled { emitTitle() } // no "|" in the layout: everything sits left
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

        case .muteAudio:
            return button(id, "Mute Sound", audioMuted ? "speaker.slash" : "speaker.wave.2",
                          #selector(toggleAudioMute))

        case .muteMic:
            return button(id, "Mute Microphone",
                          webView.microphoneCaptureState == .muted ? "mic.slash" : "mic",
                          #selector(toggleMicMute))

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
            guard let name = customName(of: id),
                  let custom = customButtons.first(where: { $0.name == name }) else { return nil }
            let item = NSToolbarItem(itemIdentifier: id)
            item.label = custom.label
            item.toolTip = custom.label
            item.image = customSymbol(customStates[name] == true ? (custom.symbolOn ?? custom.symbol) : custom.symbol,
                                      custom.label)
            item.target = self
            item.action = #selector(runCustomAction(_:))
            item.isBordered = true
            return item
        }
    }
}
