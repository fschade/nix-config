import Cocoa
import UniformTypeIdentifiers
import WebKit

// Downloads, Safari-style: a toolbar button with a progress ring that opens a
// popover listing this session's downloads — each with the file icon, name, status
// and a stop (while running) or reveal-in-Finder (when done) button. No bottom bar.

// one tracked download, active or finished
final class DownloadItem {
    enum State { case active, done, failed }
    let download: WKDownload
    var name = "Download"
    var dest: URL?
    var fraction: Double = 0
    var state: State = .active
    init(_ download: WKDownload) { self.download = download }
}

// a list-row button that remembers which download it acts on (stop / reveal)
final class DownloadActionButton: NSButton { weak var item: DownloadItem? }

// a bordered toolbar button that draws a thin accent ring for the aggregate
// progress of the running downloads (hidden when nothing is downloading).
final class DownloadsButton: NSButton {
    private let ring = CAShapeLayer()

    var progress: Double = 0 {
        didSet {
            ring.strokeEnd = CGFloat(min(max(progress, 0), 1))
            ring.isHidden = progress <= 0 || progress >= 1
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        ring.fillColor = NSColor.clear.cgColor
        ring.strokeColor = NSColor.controlAccentColor.cgColor
        ring.lineWidth = 2
        ring.lineCap = .round
        ring.isHidden = true
        layer?.addSublayer(ring)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func layout() {
        super.layout()
        ring.frame = bounds
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let path = CGMutablePath()
        // full circle from the top, clockwise; strokeEnd reveals the progress arc
        path.addArc(center: center, radius: 8.5, startAngle: .pi / 2, endAngle: -.pi * 1.5, clockwise: true)
        ring.path = path
    }
}

extension AppDelegate {
    // MARK: WKDownloadDelegate

    // save to ~/Downloads, avoiding overwrites; record the resolved name for the list
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse,
                  suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        let dir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads")
        var dest = dir.appendingPathComponent(suggestedFilename)
        let fm = FileManager.default
        var n = 1
        let ext = dest.pathExtension
        let stem = dest.deletingPathExtension().lastPathComponent
        while fm.fileExists(atPath: dest.path) {
            dest = dir.appendingPathComponent(ext.isEmpty ? "\(stem) \(n)" : "\(stem) \(n).\(ext)")
            n += 1
        }
        if let item = item(for: download) { item.name = dest.lastPathComponent; item.dest = dest }
        refreshDownloads()
        completionHandler(dest)
    }

    func downloadDidFinish(_ download: WKDownload) { finishDownload(download, state: .done) }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        finishDownload(download, state: .failed)
    }

    // MARK: tracking

    func beginDownload(_ download: WKDownload) {
        let first = downloadItems.isEmpty
        downloadItems.append(DownloadItem(download))
        // WKDownload.progress is KVO-compliant; mirror it into the item + UI
        downloadObs[ObjectIdentifier(download)] = download.progress.observe(\.fractionCompleted) { [weak self] p, _ in
            DispatchQueue.main.async {
                self?.item(for: download)?.fraction = p.fractionCompleted
                self?.refreshDownloads()
            }
        }
        if first { installToolbar() } // brings in the downloads button
        refreshDownloads()
    }

    private func finishDownload(_ download: WKDownload, state: DownloadItem.State) {
        downloadObs[ObjectIdentifier(download)] = nil
        if let item = item(for: download) {
            item.state = state
            item.fraction = state == .done ? 1 : item.fraction
        }
        refreshDownloads()
    }

    private func item(for download: WKDownload) -> DownloadItem? {
        downloadItems.first { $0.download === download }
    }

    // MARK: toolbar button

    func makeDownloadsItem(_ id: NSToolbarItem.Identifier) -> NSToolbarItem {
        let button = DownloadsButton(frame: NSRect(x: 0, y: 0, width: 32, height: 26))
        button.image = symbol("arrow.down.to.line", "Downloads")
        button.imagePosition = .imageOnly
        button.bezelStyle = .texturedRounded
        button.target = self
        button.action = #selector(showDownloads(_:))
        downloadsButton = button

        let item = NSToolbarItem(itemIdentifier: id)
        item.view = button
        item.label = "Downloads"
        item.toolTip = "Downloads"
        refreshDownloads()
        return item
    }

    private func refreshDownloads() {
        let active = downloadItems.filter { $0.state == .active }
        let aggregate = active.isEmpty ? 0 : active.map(\.fraction).reduce(0, +) / Double(active.count)
        downloadsButton?.progress = aggregate
        if downloadsPopover?.isShown == true { fillDownloadsPopover() }
    }

    // MARK: popover

    @objc private func showDownloads(_ sender: NSButton) {
        let popover = downloadsPopover ?? {
            let p = NSPopover()
            p.behavior = .transient
            p.contentViewController = NSViewController()
            p.contentViewController?.view = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 80))
            downloadsPopover = p
            return p
        }()
        fillDownloadsPopover()
        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .maxY)
    }

    // rebuild the list rows, newest on top
    private func fillDownloadsPopover() {
        guard let content = downloadsPopover?.contentViewController?.view else { return }
        content.subviews.forEach { $0.removeFromSuperview() }

        let width: CGFloat = 320, rowH: CGFloat = 52, pad: CGFloat = 8
        let rows = downloadItems.reversed()
        let height = max(rowH, CGFloat(rows.count) * rowH) + pad * 2
        content.frame = NSRect(x: 0, y: 0, width: width, height: height)

        if rows.isEmpty {
            let empty = NSTextField(labelWithString: "No downloads")
            empty.textColor = .secondaryLabelColor
            empty.frame = NSRect(x: 0, y: height / 2 - 10, width: width, height: 20)
            empty.alignment = .center
            content.addSubview(empty)
            return
        }

        var y = height - pad - rowH
        for item in rows {
            content.addSubview(downloadRow(item, width: width, height: rowH, y: y))
            y -= rowH
        }
    }

    private func downloadRow(_ item: DownloadItem, width: CGFloat, height: CGFloat, y: CGFloat) -> NSView {
        let row = NSView(frame: NSRect(x: 0, y: y, width: width, height: height))

        let icon = NSImageView(frame: NSRect(x: 12, y: (height - 32) / 2, width: 32, height: 32))
        icon.image = item.dest.map { NSWorkspace.shared.icon(forFile: $0.path) }
            ?? NSWorkspace.shared.icon(for: .data)
        row.addSubview(icon)

        let name = NSTextField(labelWithString: item.name)
        name.font = .systemFont(ofSize: 12, weight: .medium)
        name.lineBreakMode = .byTruncatingMiddle
        name.frame = NSRect(x: 52, y: height - 26, width: width - 52 - 40, height: 16)
        row.addSubview(name)

        let status = NSTextField(labelWithString: statusText(item))
        status.font = .systemFont(ofSize: 11)
        status.textColor = .secondaryLabelColor
        status.frame = NSRect(x: 52, y: 8, width: width - 52 - 40, height: 14)
        row.addSubview(status)

        if item.state == .active {
            let bar = NSProgressIndicator(frame: NSRect(x: 52, y: 24, width: width - 52 - 44, height: 6))
            bar.style = .bar
            bar.isIndeterminate = false
            bar.minValue = 0; bar.maxValue = 1; bar.doubleValue = item.fraction
            row.addSubview(bar)
        }

        // trailing: stop while running, reveal-in-Finder when done
        let action = DownloadActionButton(frame: NSRect(x: width - 34, y: (height - 22) / 2, width: 22, height: 22))
        action.isBordered = false
        action.bezelStyle = .regularSquare
        action.target = self
        action.item = item
        if item.state == .active {
            action.image = symbol("xmark.circle.fill", "Stop")
            action.action = #selector(stopDownload(_:))
        } else {
            action.image = symbol("magnifyingglass", "Show in Finder")
            action.action = #selector(revealDownload(_:))
            action.isEnabled = item.dest != nil
        }
        row.addSubview(action)

        return row
    }

    private func statusText(_ item: DownloadItem) -> String {
        switch item.state {
        case .active: return "Downloading — \(Int(item.fraction * 100))%"
        case .done: return "Completed"
        case .failed: return "Failed"
        }
    }

    @objc private func stopDownload(_ sender: DownloadActionButton) {
        sender.item?.download.cancel()
    }

    @objc private func revealDownload(_ sender: DownloadActionButton) {
        if let dest = sender.item?.dest { NSWorkspace.shared.activateFileViewerSelecting([dest]) }
    }
}
